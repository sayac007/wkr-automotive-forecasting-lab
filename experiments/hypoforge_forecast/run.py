#!/usr/bin/env python3
"""WKR forecast-side HypoForge experiment.

This does not modify the accepted WKR forecast pipeline. It uses the same
prepared historical forecast data, runs feature discovery per WKR segment on
the training period only, and writes Azure-friendly experiment artifacts.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import pandas as pd

from hypoforge import discover
from wkr_pipeline.sales_forecast_pipeline import (
    SEGMENTS,
    TRAIN_END,
    prepare_sales,
)


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--sales", required=True)
    p.add_argument("--calendar", required=True)
    p.add_argument("--market", required=True)
    p.add_argument("--output-dir", required=True)
    p.add_argument("--top-k", type=int, default=30)
    return p.parse_args()


def main():
    args = parse_args()
    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)

    df = prepare_sales(args.sales, args.calendar, args.market)
    all_rows = []

    # Discovery is deliberately isolated by segment so temporal transforms
    # cannot cross segment boundaries.
    for segment in SEGMENTS:
        d = df[(df["segment"] == segment) & (df["date"] <= TRAIN_END)].copy()
        # Keep only variables available to the existing forecast plus the target.
        cols = [
            "date",
            "log_sales",
            "holiday_intensity",
            "school_holiday_intensity",
            "summer_shutdown",
            "year_end_shutdown",
            "vehicle_production_de",
            "bev_share_pp",
        ]
        d = d[cols].dropna().sort_values("date").reset_index(drop=True)

        ranked = discover(
            d,
            target="log_sales",
            time="date",
            task="regression",
            top_k=args.top_k,
        )
        if ranked.empty:
            continue

        # FeatureSpec objects are useful in Python but not portable artifacts.
        if "spec" in ranked.columns:
            ranked["expression"] = ranked["spec"].map(repr)
            ranked = ranked.drop(columns=["spec"])
        ranked.insert(0, "segment", segment)
        all_rows.append(ranked)

    result = pd.concat(all_rows, ignore_index=True) if all_rows else pd.DataFrame()
    result.to_csv(out / "discovered_features.csv", index=False)

    summary = {
        "experiment": "WKR forecast feature discovery with HypoForge",
        "status": "completed",
        "scope": "forecast analysis only; accepted forecast pipeline unchanged",
        "training_cutoff": str(TRAIN_END.date()),
        "segments": SEGMENTS,
        "top_k_per_segment": args.top_k,
        "rows_written": int(len(result)),
        "notes": [
            "Discovery is run independently per segment.",
            "Only data through the existing training cutoff are scored.",
            "This alpha run evaluates feature hypotheses; it does not replace the accepted forecast.",
            "Results are exploratory and may motivate a later leakage-safe forecast comparison.",
        ],
    }
    (out / "experiment_summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    print("\nWKR × HYPOFORGE FORECAST EXPERIMENT")
    print("=" * 72)
    print(f"segments: {len(SEGMENTS)}")
    print(f"ranked feature rows: {len(result)}")
    if not result.empty:
        preview_cols = [c for c in ["segment", "feature", "information_score", "support"] if c in result]
        print("\nTop hypotheses:")
        print(result[preview_cols].groupby("segment", group_keys=False).head(5).to_string(index=False))
    print(f"\nArtifacts written to: {out}")


if __name__ == "__main__":
    main()
