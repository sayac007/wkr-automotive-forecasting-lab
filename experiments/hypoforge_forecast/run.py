#!/usr/bin/env python3
"""WKR baseline vs HypoForge v0.3 conservative challenger."""

from __future__ import annotations
import argparse, json
from pathlib import Path
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
from hypoforge import discover, evaluate, select_candidates
from wkr_pipeline.sales_forecast_pipeline import (
    FORMULA, SEGMENTS, TRAIN_END, TEST_START, TEST_END, metrics, prepare_sales,
)

HYPOFORGE_COMMIT="243a1f1c97ffd122be16ae4508581b32a2001d37"
DISCOVERY_COLUMNS=[
    "date","log_sales","weekday","holiday_intensity","school_holiday_intensity",
    "summer_shutdown","year_end_shutdown","vehicle_production_de","log_production","bev_share_pp",
]
BASELINE_FEATURES=[
    "weekday","holiday_intensity","school_holiday_intensity",
    "summer_shutdown","year_end_shutdown","log_production","bev_share_pp",
]
MAX_CHALLENGER_FEATURES=3

def parse_args():
    p=argparse.ArgumentParser()
    for x in ("sales","calendar","market","output-dir"): p.add_argument(f"--{x}",required=True)
    p.add_argument("--top-k",type=int,default=100)
    return p.parse_args()

def eligible(spec):
    if "log_sales" in spec.inputs or "date" in spec.inputs: return False
    if spec.op in {"lag","diff","pct_change","ewm_mean"} or spec.op.startswith("rolling_"): return False
    return spec.op!="identity"

def add_features(frame,selected):
    out=frame.copy(); names=[]
    for j,(_,row) in enumerate(selected.iterrows(),1):
        name=f"hf_{j}"; out[name]=evaluate(row["spec"],out); names.append(name)
    return out,names

def main():
    a=parse_args(); out=Path(a.output_dir); out.mkdir(parents=True,exist_ok=True)
    df=prepare_sales(a.sales,a.calendar,a.market)
    discovered=[]; selected_rows=[]; audits=[]; accuracy=[]; predictions=[]
    for segment in SEGMENTS:
        d=df[df.segment==segment].copy()
        required=["net_sales_eur","vehicle_production_de","bev_share","holiday_intensity","school_holiday_intensity"]
        observed=d.dropna(subset=required)
        train=observed[observed.date<=TRAIN_END].copy()
        test=observed[(observed.date>=TEST_START)&(observed.date<=TEST_END)].copy()

        baseline=smf.ols(FORMULA,data=train).fit()
        bp=np.maximum(0.,np.expm1(baseline.predict(test)))
        bm=metrics(test.net_sales_eur.to_numpy(),bp)

        disc=train[DISCOVERY_COLUMNS].dropna().sort_values("date").reset_index(drop=True)
        ranked=discover(disc,"log_sales",time="date",task="regression",top_k=a.top_k,lags=(),windows=())
        if not ranked.empty:
            art=ranked.copy(); art["expression"]=art.spec.map(repr)
            art=art.drop(columns=["spec"]); art.insert(0,"segment",segment); discovered.append(art)
            candidates=ranked[ranked.spec.map(eligible)].copy()
        else: candidates=pd.DataFrame()

        if not candidates.empty:
            selected,audit=select_candidates(
                disc,candidates,baseline_features=BASELINE_FEATURES,
                max_features=MAX_CHALLENGER_FEATURES,
                correlation_threshold=.98,max_condition_number=1e6,
            )
            audit.insert(0,"segment",segment); audits.append(audit)
        else: selected=pd.DataFrame()

        train_hf,names=add_features(train,selected); test_hf,_=add_features(test,selected)
        formula=FORMULA+((" + "+" + ".join(names)) if names else "")
        challenger=smf.ols(formula,data=train_hf).fit()
        hp=np.maximum(0.,np.expm1(challenger.predict(test_hf)))
        hm=metrics(test_hf.net_sales_eur.to_numpy(),hp)

        for rank,(_,row) in enumerate(selected.iterrows(),1):
            spec=row.spec
            selected_rows.append({
                "segment":segment,"rank":rank,"feature":spec.name,"op":spec.op,
                "inputs":"|".join(spec.inputs),"information_score_train":row.information_score,
                "preference_score_train":row.preference_score,"risk_penalty":row.risk_penalty,
                "expression":repr(spec),
            })
        accuracy.append({
            "segment":segment,"n_holdout":bm["n"],"baseline_mape_pct":bm["mape_pct"],
            "hypoforge_mape_pct":hm["mape_pct"],"delta_mape_pp":hm["mape_pct"]-bm["mape_pct"],
            "baseline_mae_eur":bm["mae_eur"],"hypoforge_mae_eur":hm["mae_eur"],
            "baseline_rmse_eur":bm["rmse_eur"],"hypoforge_rmse_eur":hm["rmse_eur"],
            "n_hypoforge_features":len(names),
        })
        predictions.append(pd.DataFrame({
            "date":test.date.to_numpy(),"segment":segment,"actual_net_sales_eur":test.net_sales_eur.to_numpy(),
            "baseline_forecast_eur":bp,"hypoforge_forecast_eur":hp,
        }))

    discovered_df=pd.concat(discovered,ignore_index=True) if discovered else pd.DataFrame()
    selected_df=pd.DataFrame(selected_rows)
    audit_df=pd.concat(audits,ignore_index=True) if audits else pd.DataFrame()
    acc=pd.DataFrame(accuracy); pred=pd.concat(predictions,ignore_index=True)
    ob=metrics(pred.actual_net_sales_eur,pred.baseline_forecast_eur)
    oh=metrics(pred.actual_net_sales_eur,pred.hypoforge_forecast_eur)
    overall=pd.DataFrame([{
        "segment":"ALL","n_holdout":ob["n"],"baseline_mape_pct":ob["mape_pct"],
        "hypoforge_mape_pct":oh["mape_pct"],"delta_mape_pp":oh["mape_pct"]-ob["mape_pct"],
        "baseline_mae_eur":ob["mae_eur"],"hypoforge_mae_eur":oh["mae_eur"],
        "baseline_rmse_eur":ob["rmse_eur"],"hypoforge_rmse_eur":oh["rmse_eur"],
        "n_hypoforge_features":int(acc.n_hypoforge_features.sum()),
    }])
    accout=pd.concat([acc,overall],ignore_index=True)
    discovered_df.to_csv(out/"discovered_features.csv",index=False)
    selected_df.to_csv(out/"selected_hypoforge_features.csv",index=False)
    audit_df.to_csv(out/"selection_audit.csv",index=False)
    accout.to_csv(out/"accuracy_comparison.csv",index=False)
    pred.to_csv(out/"forecast_comparison.csv",index=False)
    summary={
        "experiment":"WKR baseline vs HypoForge v0.3 conservative challenger",
        "hypoforge_commit":HYPOFORGE_COMMIT,"train_end":str(TRAIN_END.date()),
        "holdout":f"{TEST_START.date()} to {TEST_END.date()}","baseline_formula":FORMULA,
        "challenger_policy":{"max_features_per_segment":3,"discovery_fit_on_training_only":True,
          "ranking":"preference_score","correlation_threshold":.98,"max_condition_number":1e6,
          "baseline_redundancy_check":True,"complete_source_lineage":True},
        "overall":{"baseline_mape_pct":ob["mape_pct"],"hypoforge_mape_pct":oh["mape_pct"],
                   "delta_mape_pp":oh["mape_pct"]-ob["mape_pct"]},
        "limitations":["No rolling-origin incremental-value tournament yet.",
                       "Accepted WKR forecast pipeline remains unchanged."],
    }
    (out/"experiment_summary.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")
    print("\nWKR BASELINE vs HYPOFORGE v0.3 CHALLENGER\n"+"="*78)
    print(accout[["segment","baseline_mape_pct","hypoforge_mape_pct","delta_mape_pp","n_hypoforge_features"]].to_string(index=False))

if __name__=="__main__": main()
