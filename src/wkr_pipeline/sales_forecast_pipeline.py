#!/usr/bin/env python3
"""
WKR Komponenten KGaA
Sales forecasting pipeline for all six German product segments.

The analytical reference remains the R workflow. This Python implementation is
the engineering/cloud execution layer: validate inputs, engineer the agreed
calendar/market features, fit the calendar-augmented daily regressions, evaluate
Jan-Aug 2026, refit through Aug 2026, forecast Sep-Dec 2026, and persist
machine-readable diagnostics plus plots.

Synthetic WKR data only.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import scipy.stats as st
import statsmodels.api as sm
import statsmodels.formula.api as smf
from statsmodels.graphics.tsaplots import plot_acf
from statsmodels.stats.diagnostic import acorr_ljungbox
from statsmodels.stats.stattools import durbin_watson


SEGMENTS = [
    "Sealing",
    "Cable Protection",
    "Chassis NVH",
    "Powertrain Mounts",
    "Hoses & Bellows",
    "Other Automotive",
]
TRAIN_END = pd.Timestamp("2025-12-31")
TEST_START = pd.Timestamp("2026-01-01")
TEST_END = pd.Timestamp("2026-08-31")
FORECAST_START = pd.Timestamp("2026-09-01")
FORECAST_END = pd.Timestamp("2026-12-31")

# Same footprint logic as the final R modeling step: Niedersachsen receives
# double weight; the remaining represented states share equal base weight.
NDS_TOKEN = "niedersachsen"

FORMULA = (
    "log_sales ~ C(weekday) + holiday_intensity + school_holiday_intensity + "
    "summer_shutdown + year_end_shutdown + log_production + bev_share_pp"
)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--sales", required=True)
    p.add_argument("--calendar", required=True)
    p.add_argument("--market", required=True)
    p.add_argument("--market-forecast", required=True)
    p.add_argument("--output-dir", required=True)
    return p.parse_args()


def require_columns(df: pd.DataFrame, columns: list[str], label: str) -> None:
    missing = sorted(set(columns) - set(df.columns))
    if missing:
        raise ValueError(f"{label}: missing columns: {', '.join(missing)}")


def read_calendar(path: str) -> pd.DataFrame:
    # sep=None handles the legacy semicolon export and future comma exports.
    raw = pd.read_csv(path, sep=None, engine="python", encoding="utf-8-sig")
    raw.columns = [str(c).strip().lstrip("\ufeff") for c in raw.columns]
    require_columns(raw, ["Datum", "Bundesland", "Ferien"], "calendar")

    raw["date"] = pd.to_datetime(raw["Datum"], dayfirst=True, errors="coerce")
    if raw["date"].isna().any():
        raise ValueError("calendar: unparseable dates")

    holiday_cols = [
        c for c in
        ["Karfreitag", "Weihnachten", "Silvester", "ErsterMai", "Pfingsten", "Himmelfahrt"]
        if c in raw.columns
    ]
    if not holiday_cols:
        raise ValueError("calendar: no holiday timing columns found")

    for c in holiday_cols + ["Ferien"]:
        raw[c] = pd.to_numeric(raw[c], errors="coerce").fillna(0.0)

    raw["holiday_flag"] = (raw[holiday_cols].sum(axis=1) > 0).astype(float)

    states = sorted(raw["Bundesland"].astype(str).unique())
    weights = {s: (2.0 if NDS_TOKEN in s.lower() else 1.0) for s in states}
    total = sum(weights.values())
    weights = {s: w / total for s, w in weights.items()}
    raw["state_weight"] = raw["Bundesland"].astype(str).map(weights)

    raw["weighted_holiday"] = raw["holiday_flag"] * raw["state_weight"]
    raw["weighted_school"] = raw["Ferien"] * raw["state_weight"]

    daily = (
        raw.groupby("date", as_index=False)
        .agg(
            holiday_intensity=("weighted_holiday", "sum"),
            school_holiday_intensity=("weighted_school", "sum"),
        )
    )

    # The legacy calendar does not contain every Sunday/public-holiday date.
    # Missing dates therefore receive zero for these *timing* features, matching
    # the established R workflow rather than inventing new semantics.
    full = pd.DataFrame({"date": pd.date_range("2022-01-01", "2026-12-31", freq="D")})
    daily = full.merge(daily, on="date", how="left").fillna(
        {"holiday_intensity": 0.0, "school_holiday_intensity": 0.0}
    )
    daily["summer_shutdown"] = daily["date"].dt.month.isin([7, 8]).astype(int)
    daily["year_end_shutdown"] = (
        (daily["date"].dt.month == 12) & (daily["date"].dt.day >= 20)
    ).astype(int)
    return daily


def read_market(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    require_columns(
        df,
        ["month", "vehicle_production_de", "registrations_total_de", "registrations_bev"],
        "automotive market",
    )
    df["month"] = pd.to_datetime(df["month"], errors="coerce")
    if df["month"].isna().any():
        raise ValueError("automotive market: unparseable month")
    for c in ["vehicle_production_de", "registrations_total_de", "registrations_bev"]:
        df[c] = pd.to_numeric(df[c], errors="coerce")
    if (df["registrations_total_de"] <= 0).any():
        raise ValueError("automotive market: non-positive total registrations")
    df["bev_share"] = df["registrations_bev"] / df["registrations_total_de"]
    if not df["bev_share"].dropna().between(0, 1).all():
        raise ValueError("automotive market: BEV share outside [0,1]")
    return df[["month", "vehicle_production_de", "bev_share"]].copy()


def prepare_sales(sales_path: str, calendar_path: str, market_path: str) -> pd.DataFrame:
    sales = pd.read_csv(sales_path)
    require_columns(sales, ["date", "segment", "net_sales_eur"], "sales")
    sales["date"] = pd.to_datetime(sales["date"], errors="coerce")
    sales["net_sales_eur"] = pd.to_numeric(sales["net_sales_eur"], errors="coerce")
    if sales["date"].isna().any() or sales["net_sales_eur"].isna().any():
        raise ValueError("sales: invalid date or net_sales_eur")
    if (sales["net_sales_eur"] < 0).any():
        raise ValueError("sales: negative net sales")

    missing_segments = sorted(set(SEGMENTS) - set(sales["segment"].unique()))
    if missing_segments:
        raise ValueError("sales: missing segments: " + ", ".join(missing_segments))

    sales["month"] = sales["date"].dt.to_period("M").dt.to_timestamp()
    market = read_market(market_path)
    cal = read_calendar(calendar_path)

    df = sales.merge(market, on="month", how="left").merge(cal, on="date", how="left")
    df["weekday"] = pd.Categorical(
        df["date"].dt.day_name(),
        categories=["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
        ordered=False,
    )
    df["log_sales"] = np.log1p(df["net_sales_eur"])
    df["log_production"] = np.log(df["vehicle_production_de"])
    df["bev_share_pp"] = 100.0 * df["bev_share"]
    return df.sort_values(["segment", "date"]).reset_index(drop=True)


def metrics(actual: np.ndarray, predicted: np.ndarray) -> dict:
    actual = np.asarray(actual, dtype=float)
    predicted = np.asarray(predicted, dtype=float)
    err = actual - predicted
    nonzero = actual != 0
    return {
        "n": int(len(actual)),
        "mae_eur": float(np.mean(np.abs(err))),
        "rmse_eur": float(np.sqrt(np.mean(err ** 2))),
        "mape_pct": float(np.mean(np.abs(err[nonzero] / actual[nonzero])) * 100.0),
        "bias_eur": float(np.mean(predicted - actual)),
        "bias_pct_of_mean_actual": float(
            100.0 * np.mean(predicted - actual) / np.mean(actual)
        ),
    }


def residual_diagnostics(residuals: np.ndarray) -> dict:
    r = np.asarray(residuals, dtype=float)
    acf_vals = sm.tsa.stattools.acf(r, nlags=30, fft=True)
    lb = acorr_ljungbox(r, lags=[7, 14, 30], return_df=True)
    return {
        "n": int(len(r)),
        "mean_residual_log": float(np.mean(r)),
        "std_residual_log": float(np.std(r, ddof=1)),
        "durbin_watson": float(durbin_watson(r)),
        "acf_1": float(acf_vals[1]),
        "acf_7": float(acf_vals[7]),
        "acf_14": float(acf_vals[14]),
        "acf_30": float(acf_vals[30]),
        "ljung_box_p_7": float(lb.loc[7, "lb_pvalue"]),
        "ljung_box_p_14": float(lb.loc[14, "lb_pvalue"]),
        "ljung_box_p_30": float(lb.loc[30, "lb_pvalue"]),
    }


def save_plots(segment: str, train: pd.DataFrame, test: pd.DataFrame,
               model, pred: np.ndarray, plot_dir: Path) -> None:
    slug = segment.lower().replace(" ", "_").replace("&", "and")
    plot_dir.mkdir(parents=True, exist_ok=True)
    resid = np.asarray(model.resid)

    fig, ax = plt.subplots(figsize=(10, 4.5))
    ax.plot(test["date"], test["net_sales_eur"], label="Actual")
    ax.plot(test["date"], pred, label="Predicted")
    ax.set_title(f"{segment}: Jan-Aug 2026 holdout")
    ax.set_ylabel("Net sales EUR")
    ax.legend()
    fig.tight_layout()
    fig.savefig(plot_dir / f"{slug}_actual_vs_predicted.png", dpi=140)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(8, 4.5))
    plot_acf(resid, lags=30, ax=ax)
    ax.set_title(f"{segment}: training residual ACF")
    fig.tight_layout()
    fig.savefig(plot_dir / f"{slug}_residual_acf.png", dpi=140)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(6, 6))
    st.probplot(resid, dist="norm", plot=ax)
    ax.set_title(f"{segment}: residual Q-Q")
    fig.tight_layout()
    fig.savefig(plot_dir / f"{slug}_residual_qq.png", dpi=140)
    plt.close(fig)


def fit_and_evaluate_segment(df: pd.DataFrame, segment: str, plot_dir: Path) -> tuple[dict, object]:
    d = df[df["segment"] == segment].copy()
    required = [
        "net_sales_eur", "vehicle_production_de", "bev_share",
        "holiday_intensity", "school_holiday_intensity",
    ]
    observed = d.dropna(subset=required).copy()
    train = observed[observed["date"] <= TRAIN_END].copy()
    test = observed[(observed["date"] >= TEST_START) & (observed["date"] <= TEST_END)].copy()
    if len(train) < 365 or len(test) < 30:
        raise ValueError(f"{segment}: insufficient train/test rows")

    model = smf.ols(FORMULA, data=train).fit()
    pred = np.maximum(0.0, np.expm1(model.predict(test)))
    perf = metrics(test["net_sales_eur"].to_numpy(), pred)
    diag = residual_diagnostics(model.resid)

    beta_prod = float(model.params["log_production"])
    beta_bev = float(model.params["bev_share_pp"])
    structural = {
        "production_elasticity": beta_prod,
        "bev_effect_1pp_pct": float(100.0 * (math.exp(beta_bev) - 1.0)),
        "bev_effect_10pp_pct": float(100.0 * (math.exp(10.0 * beta_bev) - 1.0)),
        "r_squared_train": float(model.rsquared),
        "adjusted_r_squared_train": float(model.rsquared_adj),
    }

    save_plots(segment, train, test, model, pred, plot_dir)
    result = {
        "segment": segment,
        "train_start": str(train["date"].min().date()),
        "train_end": str(train["date"].max().date()),
        "test_start": str(test["date"].min().date()),
        "test_end": str(test["date"].max().date()),
        "holdout": perf,
        "residual_diagnostics": diag,
        "structural_coefficients": structural,
    }
    return result, model


def make_future_frame(df: pd.DataFrame, market_forecast_path: str, segment: str) -> tuple[pd.DataFrame, pd.DataFrame]:
    d = df[df["segment"] == segment].copy()
    refit = d[(d["date"] <= TEST_END) & d["vehicle_production_de"].notna()].copy()

    future = d[(d["date"] >= FORECAST_START) & (d["date"] <= FORECAST_END)].copy()
    if len(future) != 122:
        raise ValueError(f"{segment}: expected 122 Sep-Dec 2026 daily rows, got {len(future)}")

    fc = read_market(market_forecast_path)
    future = future.drop(columns=["vehicle_production_de", "bev_share", "log_production", "bev_share_pp"])
    future = future.merge(fc, on="month", how="left")
    if future[["vehicle_production_de", "bev_share"]].isna().any().any():
        raise ValueError(f"{segment}: missing Sep-Dec market forecast after merge")
    future["log_production"] = np.log(future["vehicle_production_de"])
    future["bev_share_pp"] = 100.0 * future["bev_share"]
    future = future.sort_values("date")
    return refit, future


def main() -> None:
    args = parse_args()
    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)
    plot_dir = out / "plots"

    df = prepare_sales(args.sales, args.calendar, args.market)

    diagnostics = []
    daily_forecasts = []
    model_summaries = []

    for segment in SEGMENTS:
        result, _ = fit_and_evaluate_segment(df, segment, plot_dir)
        diagnostics.append(result)

        refit, future = make_future_frame(df, args.market_forecast, segment)
        final_model = smf.ols(FORMULA, data=refit).fit()
        future["forecast_net_sales_eur"] = np.maximum(
            0.0, np.expm1(final_model.predict(future))
        )
        daily_forecasts.append(
            future[[
                "date", "segment", "forecast_net_sales_eur",
                "vehicle_production_de", "bev_share",
            ]].copy()
        )
        model_summaries.append({
            "segment": segment,
            "refit_through": str(refit["date"].max().date()),
            "production_elasticity": float(final_model.params["log_production"]),
            "bev_effect_10pp_pct": float(
                100.0 * (math.exp(10.0 * float(final_model.params["bev_share_pp"])) - 1.0)
            ),
            "r_squared_refit": float(final_model.rsquared),
        })

    daily = pd.concat(daily_forecasts, ignore_index=True)
    daily["month"] = daily["date"].dt.to_period("M").dt.to_timestamp()
    monthly = (
        daily.groupby(["month", "segment"], as_index=False)["forecast_net_sales_eur"]
        .sum()
        .sort_values(["month", "segment"])
    )
    total_monthly = (
        daily.groupby("month", as_index=False)["forecast_net_sales_eur"]
        .sum()
        .rename(columns={"forecast_net_sales_eur": "forecast_total_net_sales_eur"})
    )

    daily.to_csv(out / "sales_forecast_daily_2026_sep_dec.csv", index=False)
    monthly.to_csv(out / "sales_forecast_monthly_2026_sep_dec.csv", index=False)
    total_monthly.to_csv(out / "sales_forecast_total_monthly_2026_sep_dec.csv", index=False)

    summary = {
        "pipeline": "WKR German sales forecast",
        "data_scope": "synthetic WKR sales; real German automotive market environment",
        "model": "segment-level daily log-linear regression with calendar and market drivers",
        "train_period": "2022-01-01 to 2025-12-31",
        "holdout_period": "2026-01-01 to 2026-08-31",
        "refit_period": "through 2026-08-31",
        "forecast_period": "2026-09-01 to 2026-12-31",
        "segments": diagnostics,
        "final_models": model_summaries,
        "business_checks": {
            "segments_forecast": int(daily["segment"].nunique()),
            "daily_forecast_rows": int(len(daily)),
            "negative_forecasts": int((daily["forecast_net_sales_eur"] < 0).sum()),
            "missing_forecasts": int(daily["forecast_net_sales_eur"].isna().sum()),
            "forecast_total_sep_dec_eur": float(daily["forecast_net_sales_eur"].sum()),
        },
    }
    with open(out / "sales_forecast_diagnostics.json", "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)

    # Compact console report: useful directly in Azure logs.
    print("\nWKR SALES FORECAST PIPELINE")
    print("=" * 72)
    print("Status: model fitting, holdout evaluation and Sep-Dec forecast completed")
    print("\nHoldout Jan-Aug 2026")
    print("-" * 72)
    print(f"{'Segment':24s} {'MAE EUR':>11s} {'RMSE EUR':>11s} {'MAPE %':>8s} {'DW':>7s} {'ACF1':>7s} {'ACF7':>7s}")
    for x in diagnostics:
        h = x["holdout"]
        d = x["residual_diagnostics"]
        print(
            f"{x['segment'][:24]:24s} "
            f"{h['mae_eur']:11.0f} {h['rmse_eur']:11.0f} {h['mape_pct']:8.2f} "
            f"{d['durbin_watson']:7.3f} {d['acf_1']:7.3f} {d['acf_7']:7.3f}"
        )

    print("\nForecast Sep-Dec 2026")
    print("-" * 72)
    print(total_monthly.to_string(index=False))
    print("\nBusiness checks")
    print("-" * 72)
    for k, v in summary["business_checks"].items():
        print(f"{k}: {v}")
    print(f"\nArtifacts written to: {out}")


if __name__ == "__main__":
    main()
