# WKR Automotive Forecasting Lab

A learning-by-building project that turns a realistic automotive forecasting use case into a reproducible cloud ML system.

**WKR Komponenten KGaA is fictional. Company sales and product data are synthetic. External German automotive, calendar and weather data are used as realistic context.**

## Business question

How will German WKR sales and product mix develop over the next 6–18 months under different scenarios for vehicle production, registrations, drivetrain mix and related market drivers?

## Current state

The analytical baseline and the first cloud execution layer are working. The repository currently contains:

- reproducible synthetic product-master generation;
- reproducible German daily sales generation;
- a forecast of the German automotive market;
- segment-level daily German sales forecasting for all six WKR product segments;
- statistical holdout diagnostics including MAE, RMSE, MAPE, bias, Durbin-Watson, residual ACF and Ljung-Box tests;
- German calendar inputs and a Python calendar pipeline;
- Azure ML command-job definitions for both the calendar pipeline and the sales forecast;
- persisted Azure ML outputs for forecast results, diagnostics and plots;
- an installable Python package configured through `pyproject.toml`;
- automated tests with `pytest`;
- static code checks with Ruff;
- a GitHub Actions CI workflow running installation, linting and tests on a clean Ubuntu environment.

Two workloads have been executed successfully from the versioned GitHub repository on Azure Machine Learning:

1. the German calendar generation/validation pipeline;
2. the complete WKR German sales forecast.

The sales-forecast run also exposed a real data-contract problem in the repository: the automotive market input was missing `registrations_bev`. The input was corrected in GitHub and the unchanged Azure job was rerun successfully. This is the intended operating pattern: source and definitions live in GitHub; Azure executes a specific repository state and persists the resulting artifacts.

The first GitHub Actions CI runs also exposed real engineering issues: lint violations in the calendar pipeline and tests that still imported Python modules through the repository `src` directory. These were corrected rather than bypassed. Tests now run against the installed `wkr_pipeline` package.

The current CI pipeline is green.

## Latest validated Azure sales forecast

The first accepted cloud sales-forecast run was:

```text
Azure ML run: amiable_carrot_10g1wp89q4
Status:       Completed
Holdout:      Jan-Aug 2026
Forecast:     Sep-Dec 2026
Segments:     6
Forecast rows: 732
Missing forecasts: 0
Negative forecasts: 0
```

Holdout MAPE by segment:

```text
Sealing               13.88%
Cable Protection      16.24%
Chassis NVH           11.06%
Powertrain Mounts     10.73%
Hoses & Bellows       10.32%
Other Automotive      12.91%
```

Forecast total:

```text
Sep 2026    EUR 31.85m
Oct 2026    EUR 27.08m
Nov 2026    EUR 31.31m
Dec 2026    EUR 21.65m
-----------------------
Sep-Dec     EUR 111.89m
```

Residual diagnostics show remaining positive serial correlation across the segment models (Durbin-Watson approximately 1.23–1.27; ACF(1) approximately 0.36–0.38; ACF(7) approximately 0.24–0.27; Ljung-Box tests strongly reject residual independence). This limitation is retained explicitly rather than hidden by adding dynamics that did not improve the earlier recursive business-forecast design sufficiently.

Detailed acceptance information is recorded in [`docs/decisions/0004-first-cloud-sales-forecast.md`](docs/decisions/0004-first-cloud-sales-forecast.md).

## Architecture

See [`docs/architecture.md`](docs/architecture.md).

For the shell-based GitHub-to-Azure workflow, see [`docs/run-github-code-on-azure-ml.md`](docs/run-github-code-on-azure-ml.md).

## Repository layout

```text
R/                    analytical reference implementation and synthetic-data generators
src/wkr_pipeline/     installable Python package and production-oriented pipeline code
tests/                automated pytest tests
.github/workflows/    GitHub Actions CI
azureml/              Azure ML job/environment definitions
data/                 small project inputs and generated reference data
docs/                 architecture, data contracts, runbooks and engineering decisions
pyproject.toml        Python package, dependencies and development-tool configuration
```

## Reproducibility

R scripts use relative project paths and fixed seeds where synthetic data are generated. Azure ML jobs declare their code, inputs, outputs, environment and compute in version-controlled YAML.

For Python development, dependencies and development tools are declared in `pyproject.toml`. CI installs the project into a clean environment before running Ruff and pytest, so automated tests do not depend on a developer's local repository layout or Python path.

The current cloud execution pattern is:

```text
GitHub
  |
  v
Azure Cloud Shell / Azure CLI
  |
  v
version-controlled Azure ML YAML
  |
  v
Azure ML compute + declared environment
  |
  v
R/Python workload
  |
  v
named Azure ML outputs
  |
  v
technical + statistical + business validation
```

Generated Azure run artifacts are retained by Azure ML rather than committed back to the repository.

## Engineering roadmap

The forecasting workload is now the stable analytical base. The next goal is to turn it into a small but realistic ML decision system rather than treating infrastructure technologies as isolated learning exercises.

Current engineering status:

```text
Forecasting baseline             done
Azure ML execution               done
Installable Python package       done
Automated tests                  done
Ruff static checks               done
GitHub Actions CI                done
Experiment tracking             next
```

The next planned step is **MLflow experiment tracking** for the existing forecasting workload.

After that, WKR will evolve incrementally toward:

```text
forecast
  -> experiment tracking and reproducibility
  -> containerized serving / API
  -> cloud deployment
  -> logging, monitoring and observability
  -> forecast-to-decision layer
  -> agent/tool integration
  -> systematic evaluation
```

Where mature open-source solutions already exist, WKR will reuse and adapt established patterns rather than reimplementing infrastructure for its own sake. Project-specific development will focus increasingly on the automotive forecasting and decision problem.

Relevant ecosystems and reference projects include sktime and PyTorch Forecasting for forecasting, MLflow for experiment tracking and observability, and established MLOps and serving projects for later production stages.
