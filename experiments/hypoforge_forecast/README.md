# WKR × HypoForge forecast challenger

Controlled holdout comparison against the accepted WKR baseline. The accepted
pipeline itself is unchanged.

The experiment recreates the exact baseline formula and exact Jan-Aug 2026
holdout, discovers candidates on training data through 2025-12-31 only, selects
at most three non-redundant challenger features per segment, refits the same OLS
model class, and compares daily holdout accuracy.

For this first challenger, raw date, target-derived features and temporal
lag/rolling/difference/EWMA hypotheses are excluded. Those require explicit
forecast-origin semantics in HypoForge first. Identity features are excluded
because the baseline already contains the original drivers.

HypoForge is installed from GitHub pinned to commit:
`68ffe578c09eecf9500cee172fc74d0a727ef7a4`

Artifacts:
- `accuracy_comparison.csv`
- `forecast_comparison.csv`
- `selected_hypoforge_features.csv`
- `discovered_features.csv`
- `experiment_summary.json`

`delta_mape_pp = HypoForge MAPE - baseline MAPE`, so negative values mean lower
holdout MAPE for the challenger.

Submit from the WKR repository root:

```bash
az ml job create \
  --file experiments/hypoforge_forecast/azure_job.yml \
  --resource-group rg-wkr-ml \
  --workspace-name mrw-wkr-forecasting
```
