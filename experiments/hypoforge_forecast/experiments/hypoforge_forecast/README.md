# WKR × HypoForge forecast experiment

Isolated Azure ML experiment. The accepted WKR forecast pipeline is unchanged.

## HypoForge dependency

Azure installs HypoForge directly from its public GitHub repository, pinned to:

`68ffe578c09eecf9500cee172fc74d0a727ef7a4`

The previous clone/PYTHONPATH workaround has been removed. A successful Azure
environment build therefore also verifies that HypoForge can be consumed as an
independent Python package from GitHub.

## Experiment

The existing WKR synthetic daily sales data are regenerated. Feature discovery
then runs independently for each WKR segment using observations only through the
existing training cutoff. Results do not feed back into the accepted forecast.

Expected Azure artifacts:

- `discovered_features.csv`
- `experiment_summary.json`

The summary records the pinned HypoForge commit and the installed module path.

Submit from the WKR repository root:

```bash
az ml job create \
  --file experiments/hypoforge_forecast/azure_job.yml \
  --resource-group rg-wkr-ml \
  --workspace-name mrw-wkr-forecasting
```
