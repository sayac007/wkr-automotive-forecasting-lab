#!/usr/bin/env python3
"""Leakage-conscious WKR baseline vs HypoForge challenger experiment."""

from __future__ import annotations
import argparse, json
from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.formula.api as smf

from hypoforge import discover, evaluate
from wkr_pipeline.sales_forecast_pipeline import (
    FORMULA, SEGMENTS, TRAIN_END, TEST_START, TEST_END, metrics, prepare_sales,
)

HYPOFORGE_COMMIT = "68ffe578c09eecf9500cee172fc74d0a727ef7a4"

DISCOVERY_COLUMNS = [
    "date", "log_sales", "holiday_intensity", "school_holiday_intensity",
    "summer_shutdown", "year_end_shutdown", "vehicle_production_de", "bev_share_pp",
]

# First challenger deliberately stays small. We want incremental forecast evidence,
# not 30 near-equivalent monotone versions of the same driver.
MAX_CHALLENGER_FEATURES = 3


def parse_args():
    p=argparse.ArgumentParser()
    p.add_argument("--sales",required=True)
    p.add_argument("--calendar",required=True)
    p.add_argument("--market",required=True)
    p.add_argument("--output-dir",required=True)
    p.add_argument("--top-k",type=int,default=50)
    return p.parse_args()


def _source_family(spec):
    # Redundancy guard: one challenger per primary source signal.
    return spec.inputs[0]


def _eligible(spec):
    # Keep this first forecast comparison intentionally conservative.
    # Exclude raw date, target-derived features and temporal transforms until
    # HypoForge has explicit forecast-origin/availability semantics.
    if "log_sales" in spec.inputs or "date" in spec.inputs:
        return False
    if spec.op in {"lag","diff","pct_change","ewm_mean"} or spec.op.startswith("rolling_"):
        return False
    # Identity variables already represented by the baseline do not make a challenger.
    if spec.op == "identity":
        return False
    return True


def select_specs(ranked):
    chosen=[]; families=set()
    for _, row in ranked.iterrows():
        spec=row["spec"]
        fam=_source_family(spec)
        if not _eligible(spec) or fam in families:
            continue
        chosen.append((spec,float(row["information_score"])))
        families.add(fam)
        if len(chosen)>=MAX_CHALLENGER_FEATURES:
            break
    return chosen


def add_features(frame, selected):
    out=frame.copy()
    names=[]
    for i,(spec,_) in enumerate(selected,1):
        name=f"hf_{i}"
        out[name]=evaluate(spec,out)
        names.append(name)
    return out,names


def main():
    a=parse_args()
    out=Path(a.output_dir); out.mkdir(parents=True,exist_ok=True)
    df=prepare_sales(a.sales,a.calendar,a.market)

    discovered=[]; selected_rows=[]; accuracy=[]; predictions=[]

    for segment in SEGMENTS:
        d=df[df["segment"]==segment].copy()
        required=["net_sales_eur","vehicle_production_de","bev_share",
                  "holiday_intensity","school_holiday_intensity"]
        observed=d.dropna(subset=required).copy()
        train=observed[observed["date"]<=TRAIN_END].copy()
        test=observed[(observed["date"]>=TEST_START)&(observed["date"]<=TEST_END)].copy()

        # Baseline: exact accepted formula, exact accepted split.
        baseline=smf.ols(FORMULA,data=train).fit()
        baseline_pred=np.maximum(0.0,np.expm1(baseline.predict(test)))
        base_m=metrics(test["net_sales_eur"].to_numpy(),baseline_pred)

        # Discovery and all data-derived Hill/threshold parameters are fitted
        # strictly on training rows. Holdout is never passed to discover().
        disc_train=train[DISCOVERY_COLUMNS].dropna().sort_values("date").reset_index(drop=True)
        ranked=discover(
            disc_train,target="log_sales",time="date",task="regression",
            top_k=a.top_k,
            # Target-history transforms are intentionally disabled for this first
            # challenger; forecast-origin semantics come later.
            lags=(),windows=(),
        )
        if not ranked.empty:
            art=ranked.copy()
            art["expression"]=art["spec"].map(repr)
            art=art.drop(columns=["spec"])
            art.insert(0,"segment",segment)
            discovered.append(art)

        selected=select_specs(ranked) if not ranked.empty else []
        train_hf,names=add_features(train,selected)
        test_hf,_=add_features(test,selected)

        formula=FORMULA
        if names:
            formula += " + " + " + ".join(names)
        challenger=smf.ols(formula,data=train_hf).fit()
        challenger_pred=np.maximum(0.0,np.expm1(challenger.predict(test_hf)))
        chall_m=metrics(test_hf["net_sales_eur"].to_numpy(),challenger_pred)

        for rank,(spec,score) in enumerate(selected,1):
            selected_rows.append({
                "segment":segment,"rank":rank,"feature":spec.name,"op":spec.op,
                "inputs":"|".join(spec.inputs),"information_score_train":score,
                "expression":repr(spec),
            })

        accuracy.append({
            "segment":segment,
            "n_holdout":base_m["n"],
            "baseline_mape_pct":base_m["mape_pct"],
            "hypoforge_mape_pct":chall_m["mape_pct"],
            "delta_mape_pp":chall_m["mape_pct"]-base_m["mape_pct"],
            "baseline_mae_eur":base_m["mae_eur"],
            "hypoforge_mae_eur":chall_m["mae_eur"],
            "baseline_rmse_eur":base_m["rmse_eur"],
            "hypoforge_rmse_eur":chall_m["rmse_eur"],
            "n_hypoforge_features":len(names),
        })
        predictions.append(pd.DataFrame({
            "date":test["date"].to_numpy(),
            "segment":segment,
            "actual_net_sales_eur":test["net_sales_eur"].to_numpy(),
            "baseline_forecast_eur":baseline_pred,
            "hypoforge_forecast_eur":challenger_pred,
        }))

    discovered_df=pd.concat(discovered,ignore_index=True) if discovered else pd.DataFrame()
    selected_df=pd.DataFrame(selected_rows)
    accuracy_df=pd.DataFrame(accuracy)
    prediction_df=pd.concat(predictions,ignore_index=True)

    # Overall comparison is calculated from all daily holdout predictions,
    # not as an unweighted average of segment MAPEs.
    overall_base=metrics(prediction_df.actual_net_sales_eur, prediction_df.baseline_forecast_eur)
    overall_hf=metrics(prediction_df.actual_net_sales_eur, prediction_df.hypoforge_forecast_eur)
    overall=pd.DataFrame([{
        "segment":"ALL",
        "n_holdout":overall_base["n"],
        "baseline_mape_pct":overall_base["mape_pct"],
        "hypoforge_mape_pct":overall_hf["mape_pct"],
        "delta_mape_pp":overall_hf["mape_pct"]-overall_base["mape_pct"],
        "baseline_mae_eur":overall_base["mae_eur"],
        "hypoforge_mae_eur":overall_hf["mae_eur"],
        "baseline_rmse_eur":overall_base["rmse_eur"],
        "hypoforge_rmse_eur":overall_hf["rmse_eur"],
        "n_hypoforge_features":int(accuracy_df.n_hypoforge_features.sum()),
    }])
    accuracy_out=pd.concat([accuracy_df,overall],ignore_index=True)

    discovered_df.to_csv(out/"discovered_features.csv",index=False)
    selected_df.to_csv(out/"selected_hypoforge_features.csv",index=False)
    accuracy_out.to_csv(out/"accuracy_comparison.csv",index=False)
    prediction_df.to_csv(out/"forecast_comparison.csv",index=False)

    summary={
        "experiment":"WKR baseline vs HypoForge challenger",
        "hypoforge_commit":HYPOFORGE_COMMIT,
        "train_end":str(TRAIN_END.date()),
        "holdout":f"{TEST_START.date()} to {TEST_END.date()}",
        "baseline_formula":FORMULA,
        "challenger_policy":{
            "max_features_per_segment":MAX_CHALLENGER_FEATURES,
            "discovery_fit_on_training_only":True,
            "one_feature_per_primary_source_family":True,
            "excluded":["raw date","target-derived features","lag/diff/pct/rolling/EWMA","identity"],
        },
        "overall":{
            "baseline_mape_pct":overall_base["mape_pct"],
            "hypoforge_mape_pct":overall_hf["mape_pct"],
            "delta_mape_pp":overall_hf["mape_pct"]-overall_base["mape_pct"],
        },
        "important_limitations":[
            "Feature selection is still based on in-sample training mutual information.",
            "This is a first controlled challenger, not the final HypoForge tournament.",
            "The accepted WKR forecast pipeline is not modified.",
        ],
    }
    (out/"experiment_summary.json").write_text(json.dumps(summary,indent=2,ensure_ascii=False),encoding="utf-8")

    print("\nWKR BASELINE vs HYPOFORGE CHALLENGER")
    print("="*78)
    print(accuracy_out[["segment","baseline_mape_pct","hypoforge_mape_pct","delta_mape_pp","n_hypoforge_features"]].to_string(index=False))
    print(f"\nArtifacts written to: {out}")


if __name__=="__main__":
    main()
