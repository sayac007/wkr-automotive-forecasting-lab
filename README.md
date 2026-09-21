# WKR × HypoForge forecast experiment

Small, isolated Azure ML experiment for the existing WKR forecast use case.

## Purpose

Use HypoForge against the historical inputs of the accepted WKR sales forecast
and persist ranked feature hypotheses as Azure ML artifacts. The accepted WKR
forecast pipeline, its model formula, and its Azure job are not changed.

## Isolation rules

- Discovery runs separately for each WKR segment.
- Only observations through the existing training cutoff (2025-12-31) are scored.
- The experiment is exploratory: HypoForge does not replace or refit the accepted
  WKR forecast in this alpha step.
- Output is written only to the experiment output folder.

## HypoForge source

Repository:
`https://github.com/sayac007/HypoForge-Feature-Discovery-v0.2`

The current repository was uploaded in a flat package layout. Until its
`pyproject.toml` package mapping is corrected, this Azure experiment clones the
repository into `.external/hypoforge` and imports it through `PYTHONPATH`.
That still tests the GitHub-hosted library without copying its source into WKR.

After the HypoForge packaging metadata is fixed, replace the clone/PYTHONPATH
bootstrap with a pinned `pip install git+...@<commit>`.

## Azure ML

Submit from the WKR repository root:

    az ml job create --file experiments/hypoforge_forecast/azure_job.yml

Expected artifacts:

- `discovered_features.csv`
- `experiment_summary.json`

The Azure job first regenerates the synthetic WKR daily sales data exactly as
the existing forecast job does, then runs the isolated HypoForge analysis.
