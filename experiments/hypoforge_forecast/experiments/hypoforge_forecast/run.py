#!/usr/bin/env python3
"""Isolated WKR forecast-side HypoForge experiment."""

from __future__ import annotations
import argparse
import json
from pathlib import Path
import pandas as pd
import hypoforge
from hypoforge import discover
from wkr_pipeline.sales_forecast_pipeline import SEGMENTS, TRAIN_END, prepare_sales

HYPOFORGE_COMMIT = "68ffe578c09eecf9500cee172fc74d0a727ef7a4"

def parse_args():
    p=argparse.ArgumentParser()
    p.add_argument("--sales",required=True)
    p.add_argument("--calendar",required=True)
    p.add_argument("--market",required=True)
    p.add_argument("--output-dir",required=True)
    p.add_argument("--top-k",type=int,default=30)
    return p.parse_args()

def main():
    a=parse_args()
    out=Path(a.output_dir); out.mkdir(parents=True,exist_ok=True)
    df=prepare_sales(a.sales,a.calendar,a.market)
    rows=[]
    for segment in SEGMENTS:
        d=df[(df["segment"]==segment)&(df["date"]<=TRAIN_END)].copy()
        cols=["date","log_sales","holiday_intensity","school_holiday_intensity",
              "summer_shutdown","year_end_shutdown","vehicle_production_de","bev_share_pp"]
        d=d[cols].dropna().sort_values("date").reset_index(drop=True)
        ranked=discover(d,target="log_sales",time="date",task="regression",top_k=a.top_k)
        if ranked.empty: continue
        if "spec" in ranked:
            ranked["expression"]=ranked["spec"].map(repr)
            ranked=ranked.drop(columns=["spec"])
        ranked.insert(0,"segment",segment)
        rows.append(ranked)
    result=pd.concat(rows,ignore_index=True) if rows else pd.DataFrame()
    result.to_csv(out/"discovered_features.csv",index=False)
    summary={
      "experiment":"WKR forecast feature discovery with HypoForge",
      "status":"completed",
      "scope":"forecast analysis only; accepted forecast pipeline unchanged",
      "hypoforge_commit":HYPOFORGE_COMMIT,
      "hypoforge_module":str(Path(hypoforge.__file__).resolve()),
      "training_cutoff":str(TRAIN_END.date()),
      "segments":SEGMENTS,
      "top_k_per_segment":a.top_k,
      "rows_written":int(len(result)),
      "notes":[
        "HypoForge is installed as a pinned GitHub dependency in the Azure environment.",
        "Discovery is run independently per segment.",
        "Only data through the existing training cutoff are scored.",
        "This alpha experiment ranks hypotheses; it does not replace the accepted forecast."
      ]
    }
    (out/"experiment_summary.json").write_text(json.dumps(summary,indent=2,ensure_ascii=False),encoding="utf-8")
    print("WKR x HYPOFORGE FORECAST EXPERIMENT")
    print(f"HypoForge: {hypoforge.__file__}")
    print(f"commit: {HYPOFORGE_COMMIT}")
    print(f"ranked feature rows: {len(result)}")
    print(f"artifacts: {out}")

if __name__=="__main__":
    main()
