# WKR × HypoForge v0.3 challenger

Final controlled rerun against the frozen WKR baseline using HypoForge 0.3.0,
pinned to commit `243a1f1c97ffd122be16ae4508581b32a2001d37`.

v0.3 candidate admission uses `preference_score`, numerical-risk penalties,
redundancy checks against baseline and already-selected features, a standardized
condition-number guard, and complete source lineage. The holdout remains Jan-Aug 2026.

New artifact: `selection_audit.csv`. The accepted WKR pipeline is unchanged.
