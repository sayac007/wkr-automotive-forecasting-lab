# ADR 0003: First Successful Azure ML Job

**Date:** 2026-09-19  
**Status:** Accepted

## Context

The WKR Automotive Forecasting Lab is being extended from a local analytical workflow into a reproducible cloud-based ML/data pipeline.

The first cloud milestone was deliberately kept small: execute the existing German calendar pipeline as an Azure Machine Learning command job without editing the Python code inside Azure.

GitHub remains the source of truth for code and job definitions. Azure ML provides execution, compute, input/output handling, run metadata, and persisted artifacts.

## Implementation

The job was submitted from Azure Cloud Shell using `azureml/calendar_job.yml`.

- **Azure ML workspace:** `mrw-wkr-forecasting`
- **Resource group:** `rg-wkr-ml`
- **Region:** Poland Central
- **Compute:** `cpu-cluster`
- **Experiment:** `wkr-calendar`
- **Display name:** `wkr-calendar-pipeline`
- **Azure ML run:** `coral_pear_6pll5ty44w`
- **Git branch:** `main`
- **Git commit:** `6e5fb77da2f35b5b186fb953e82f6a2cbf259915`

Azure ML associated the submitted job with the Git repository and commit, uploaded the code snapshot and legacy calendar input, constructed the declared environment, executed the Python pipeline, and persisted the named outputs.

## Result

The Azure ML job completed successfully with no reported error.

Persisted business outputs:

- `calendar/datumlanderferienfeiertage.csv`
- `comparison/calendar_comparison_summary.json`
- `comparison/calendar_comparison_mismatches.csv`

Comparison against the historical WKR calendar:

| Feature | Match rate |
|---|---:|
| Ferien | 97.7952% |
| Karfreitag | 100.0000% |
| Weihnachten | 99.8017% |
| Silvester | 100.0000% |
| ErsterMai | 100.0000% |
| Pfingsten | 100.0000% |
| Himmelfahrt | 100.0000% |

Additional statistics:

- Generated rows: 21,443
- Legacy rows: 21,199
- Common rows: 21,181
- Legacy-only rows: 18
- Generated-only rows: 262
- `Ferien` mismatches on common rows: 467
- `Weihnachten` mismatches on common rows: 42

The differences are retained for explicit investigation rather than being silently forced to match the legacy implementation.

## Decision

The first Azure ML execution pattern is accepted as the reference cloud execution pattern for the WKR project:

**GitHub source → declarative Azure ML job definition → Azure compute → persisted named outputs and run metadata**

No application code needs to be edited interactively in Azure.

Generated run outputs remain Azure ML artifacts rather than being committed to GitHub. GitHub stores the code, configuration, documentation, tests, and architectural decisions required to reproduce the run.

## Consequences

This establishes the first working cloud execution path for WKR and demonstrates that the local Python pipeline can run reproducibly outside the development machine.

The next engineering step is to evolve from a single Azure ML command job toward an Azure ML pipeline composed of explicit reusable components, while keeping the underlying business logic independent of the cloud platform.
