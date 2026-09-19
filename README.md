# WKR Automotive Forecasting Lab

A learning-by-building project that turns a realistic automotive forecasting use case into a reproducible cloud ML system.

**WKR Komponenten KGaA is fictional. Company sales and product data are synthetic. External German automotive, calendar and weather data are used as realistic context.**

## Business question

How will German WKR sales and product mix develop over the next 6–18 months under different scenarios for vehicle production, registrations, drivetrain mix and related market drivers?

## Current state

The analytical prototype is working. The repository currently contains:

- reproducible synthetic product-master generation;
- reproducible German daily sales generation;
- a forecast of the German automotive market;
- a first daily sales model for **Powertrain Mounts**;
- German calendar inputs and a new Python calendar pipeline;
- an Azure ML command-job definition for the calendar pipeline.

The next engineering milestone is deliberately small: run the calendar pipeline as an Azure ML job and retain its validated output and comparison metrics as Azure artifacts.

## Architecture

See [`docs/architecture.md`](docs/architecture.md).

## Repository layout

```text
R/                  analytical reference implementation and synthetic-data generators
src/wkr_pipeline/   production-oriented Python pipeline code
tests/              automated tests
azureml/            Azure ML job/environment definitions
data/               small project inputs and generated reference data
docs/               architecture, data contracts and engineering decisions
```

## Reproducibility

R scripts use relative project paths and fixed seeds where synthetic data are generated. The Python calendar job validates its output and can compare it with the legacy manually maintained calendar.

## Current engineering roadmap

Local reproducible workflow → Azure ML job → Azure ML components/pipeline → CI/CD → Docker → Kubernetes/AKS → serving/API → RAG/evaluation → MCP/agent integration.

The roadmap is intentionally incremental: each layer is added to the same WKR workload rather than as a disconnected technology demo.
