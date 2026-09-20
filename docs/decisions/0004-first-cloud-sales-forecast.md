# ADR 0004: Accept first cloud sales forecast

**Date:** 2026-09-20  
**Status:** Accepted

## Context

The WKR project needs a complete, reproducible sales-forecast workload before the repository is extended into CI/CD, containerization, orchestration, serving and AI integration.

The analytical logic had already been developed and inspected in the R reference workflow. The purpose of the Python/Azure implementation is therefore not to restart model research, but to establish a cloud-executable forecasting workload with explicit inputs, outputs, diagnostics and business validation.

The Azure ML command job:

```text
azureml/sales_forecast_job.yml
```

regenerates the synthetic daily German WKR sales with the existing R generator and then executes the Python sales-forecast pipeline for all six product segments.

## First execution and data-contract failure

The first Azure execution reached the R sales generator but stopped with:

```text
Error: Missing automotive market columns: registrations_bev
Execution halted
```

The failure was traced to the version-controlled input:

```text
data/raw/automotive_market_de.csv
```

which did not contain the `registrations_bev` field required by the existing sales generator.

The input data contract was corrected in GitHub. No interactive production-code fix was made in Azure. The Cloud Shell repository was updated with `git pull` and the same Azure ML job definition was submitted again.

This failure/recovery cycle is considered desirable evidence of the intended operating model:

```text
Azure run
    |
    v
reproducible failure
    |
    v
source-of-truth correction in GitHub
    |
    v
new Git commit
    |
    v
git pull
    |
    v
new Azure run
```

## Accepted Azure run

The successful rerun was:

```text
Workspace:    mrw-wkr-forecasting
Resource group: rg-wkr-ml
Experiment:   wkr-sales-forecast
Display name: wkr-sales-forecast
Run ID:       amiable_carrot_10g1wp89q4
Status:       Completed
```

The run produced forecasts for all six WKR segments.

Technical output checks:

```text
segments_forecast:          6
daily_forecast_rows:      732
negative_forecasts:         0
missing_forecasts:          0
forecast_total_sep_dec: EUR 111,894,016
```

## Holdout evaluation

Training period:

```text
2022-01-01 to 2025-12-31
```

Holdout period:

```text
2026-01-01 to 2026-08-31
```

Results:

| Segment | MAE (EUR) | RMSE (EUR) | MAPE | Bias vs mean actual |
| --- | ---: | ---: | ---: | ---: |
| Sealing | 18,260 | 27,426 | 13.88% | -4.47% |
| Cable Protection | 13,426 | 18,958 | 16.24% | -8.49% |
| Chassis NVH | 18,101 | 27,853 | 11.06% | -4.21% |
| Powertrain Mounts | 15,091 | 24,147 | 10.73% | -1.09% |
| Hoses & Bellows | 14,431 | 21,304 | 10.32% | -3.94% |
| Other Automotive | 7,195 | 10,524 | 12.91% | -3.22% |

## Residual diagnostics

The residual diagnostics consistently show remaining positive serial correlation.

| Segment | Durbin-Watson | ACF(1) | ACF(7) |
| --- | ---: | ---: | ---: |
| Sealing | 1.250 | 0.374 | 0.263 |
| Cable Protection | 1.248 | 0.375 | 0.243 |
| Chassis NVH | 1.244 | 0.378 | 0.257 |
| Powertrain Mounts | 1.260 | 0.369 | 0.267 |
| Hoses & Bellows | 1.232 | 0.383 | 0.245 |
| Other Automotive | 1.274 | 0.362 | 0.239 |

Ljung-Box tests at the recorded lags strongly reject residual independence for every segment.

This is accepted as a known limitation of the v1 forecasting specification. Earlier analytical work investigated autoregressive terms; improved one-step dynamics did not justify introducing them into the recursive business forecast. The residual dependence is therefore reported explicitly rather than hidden by changing the agreed model at the cloud-engineering stage.

## Structural checks

The fitted market effects are directionally consistent with the WKR business design.

For Powertrain Mounts, the holdout model estimated:

```text
production elasticity:       0.342
effect of +10pp BEV share:  -6.02%
```

After refitting through August 2026:

```text
production elasticity:       0.370
effect of +10pp BEV share:  -6.05%
```

The stability of the Powertrain Mounts BEV effect is particularly relevant because this segment has the strongest negative BEV exposure in the synthetic WKR product mix.

Smaller BEV coefficients in less drivetrain-sensitive segments are not treated as structural causal estimates. Some change sign after the final refit and are interpreted as small effects around zero rather than as business conclusions.

## Forecast

The accepted total German WKR sales forecast is:

| Month | Forecast net sales |
| --- | ---: |
| September 2026 | EUR 31.85m |
| October 2026 | EUR 27.08m |
| November 2026 | EUR 31.31m |
| December 2026 | EUR 21.65m |
| **Sep-Dec 2026** | **EUR 111.89m** |

The monthly pattern is consistent with the underlying automotive-production forecast and WKR calendar logic. The lower December value is consistent with lower forecast German vehicle production and the explicit year-end shutdown feature.

## Decision

The Azure sales forecast v1 is accepted as the project's reproducible forecasting baseline.

Acceptance means:

- the Azure ML job executes successfully from version-controlled repository definitions;
- all six segment models run;
- the complete forecast horizon is produced;
- no forecasts are missing or negative;
- holdout accuracy is adequate for the project baseline;
- structural effects are directionally plausible;
- known residual autocorrelation is measured and retained as an explicit model limitation;
- the Sep-Dec 2026 aggregate and monthly profile are business-plausible.

The purpose of subsequent work is not to optimize this forecast indefinitely. This workload is now the stable system on which production engineering will be learned and implemented.

## Consequences

The next project phase can focus on productionization:

```text
forecast workload
    -> automation / CI/CD
    -> containerization
    -> orchestration and scaling
    -> serving and monitoring
    -> AI/RAG/MCP integration
```

Future model improvements remain possible, but they should be motivated by a concrete forecasting requirement rather than introduced merely to improve in-sample diagnostics.
