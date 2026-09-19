# ADR 0002 — R as analytical reference, Python for engineering pipeline

**Status:** Accepted

## Context

The forecasting logic already exists and has been validated in R. Rewriting modelling logic merely to change language would add risk without adding much learning value.

## Decision

Keep the current R implementation as the analytical reference. Introduce Python for reproducible pipeline execution, external-data ingestion, validation, Azure ML integration and later production tooling.

## Consequences

- Existing modelling work is preserved.
- Cross-language parity can be used as an acceptance check where useful.
- Python work is focused on engineering rather than re-learning modelling basics.
