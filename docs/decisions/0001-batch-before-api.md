# ADR 0001 — Batch pipeline before forecast API

**Status:** Accepted

## Context

The WKR forecasting workload naturally produces scheduled forecasts and evaluation artifacts. An API would be useful later for serving approved forecasts or scenarios, but it is not the natural first execution model.

## Decision

Build a reproducible batch workflow first and run it in Azure ML before introducing an API.

## Consequences

- Azure learning starts with jobs, artifacts, environments and lineage.
- The same workload can later be containerized and orchestrated.
- API design is postponed until there is a concrete serving requirement.
