# WKR Sales Forecast Pipeline

## Purpose

This is the cloud-executable engineering version of the established WKR sales
forecast. The analytical reference remains the R workflow; the Python pipeline
turns the agreed model into a reproducible Azure ML workload.

The job deliberately regenerates the synthetic daily sales with the existing
base-R generator before running the Python forecast. `data/sales/` therefore
remains generated data and does not need to be committed.

## Execution flow

```text
Committed WKR inputs
        |
        v
R/generate_sales_daily_de.R
        |
        v
synthetic daily German sales
        |
        v
Python validation + feature engineering
        |
        v
six segment-level daily models
        |
        +--> Jan-Aug 2026 holdout evaluation
        |      MAE / RMSE / MAPE / bias
        |      Durbin-Watson
        |      residual ACF
        |      Ljung-Box
        |      ACF / Q-Q / actual-vs-predicted plots
        |
        v
refit through Aug 2026
        |
        v
Sep-Dec 2026 forecast
        |
        v
Azure ML named output
```

## Model

Each of the six segments uses the same deliberately transparent v1
specification:

```text
log(1 + daily net sales)
    ~ weekday
    + weighted holiday timing
    + weighted school-holiday timing
    + Jul/Aug shutdown proxy
    + year-end shutdown proxy
    + log(German vehicle production)
    + BEV registration share
```

No AR term is used. Earlier R diagnostics showed that one-step AR gains did not
survive the recursive business forecast horizon strongly enough to justify the
extra dynamics in v1.

Training is 2022-01-01 through 2025-12-31. Jan-Aug 2026 is the holdout.
The final models are refit through 2026-08-31 and forecast Sep-Dec 2026 using the
committed automotive market forecast.

## Azure outputs

The named output `forecast` contains:

```text
sales_forecast_daily_2026_sep_dec.csv
sales_forecast_monthly_2026_sep_dec.csv
sales_forecast_total_monthly_2026_sep_dec.csv
sales_forecast_diagnostics.json
plots/
    <segment>_actual_vs_predicted.png
    <segment>_residual_acf.png
    <segment>_residual_qq.png
```

`Completed` is only the technical execution result. The acceptance step is the
diagnostics JSON plus forecast plausibility.

## Submit from Azure Cloud Shell

From the repository root:

```bash
az ml job create --file azureml/sales_forecast_job.yml --resource-group rg-wkr-ml --workspace-name mrw-wkr-forecasting
```

Use the returned Azure job name for `show`, `stream`, and `download`.

## Design boundary

This commit intentionally creates one coherent Azure ML command job, not a
large Azure component DAG. It gives the project a real forecast workload that
can subsequently be productionized through CI/CD, containers, orchestration,
serving, monitoring, and AI integration without turning the forecasting model
itself into the learning exercise.
