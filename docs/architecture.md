# Architecture

## Current system

```text
External data                         Synthetic WKR data
─────────────                         ──────────────────
German automotive market             Product master
DWD-derived weather                   Daily German sales
German school/public calendar
        │                                   │
        └──────────────┬────────────────────┘
                       ▼
             Data validation / features
                       │
              ┌────────┴────────┐
              ▼                 ▼
      Automotive-market     Segment sales
          forecast            modelling
              │                 │
              └────────┬────────┘
                       ▼
                Evaluation
                       │
                       ▼
              Forecast artifacts
```

## Engineering transition

The existing R implementation is the trusted analytical reference. Python is introduced where it creates engineering value: reproducible pipeline execution, external-data ingestion, validation, Azure ML jobs and later orchestration.

The first cloud workload is the calendar pipeline:

```text
External holiday source
        ↓
fetch / normalize
        ↓
WKR calendar business rules
        ↓
validation
        ↓
legacy comparison
        ↓
versioned Azure ML artifacts
```

This workload is intentionally used before the forecasting model because failures are then infrastructure/data-engineering failures rather than modelling ambiguity.

## Target evolution

```text
GitHub
  │  code + tests + configuration + infrastructure definitions
  ▼
CI/CD
  │
  ├── tests / validation
  └── controlled Azure execution
          │
          ▼
      Azure ML
      jobs → components → pipeline
          │
          ▼
   versioned artifacts / lineage
          │
          ▼
 Docker / registry → Kubernetes / AKS
          │
          ▼
     later serving/API
```

GitHub is the source of truth for code and definitions. Azure provides compute and platform services. Large production data and run artifacts should live in appropriate cloud storage/artifact stores rather than Git.
