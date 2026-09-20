# WKR Automotive Forecasting Lab --- Project Status and Continuation Context

**Status date:** 2026-09-20\
**Purpose:** Durable handover/context document for continuing the
project in a fresh ChatGPT conversation or with another engineer.\
**Repository:** `sayac007/wkr-automotive-forecasting-lab`\
**Primary working language:** German\
**Project mode:** Learning by building one serious end-to-end
forecasting/AI engineering system rather than completing disconnected
tutorials.

------------------------------------------------------------------------

## 1. Executive summary

The WKR Automotive Forecasting Lab is a realistic learning-by-building
project designed to bridge an already strong quantitative/data-science
background into modern AI/ML engineering, cloud productionization,
deployment and agentic/GenAI systems.

The central principle is:

> Build one coherent, credible workload deeply enough that every new
> engineering layer solves a real problem in the same system.

The project uses the fictional German automotive supplier **WKR
Komponenten KGaA**. WKR company/product/sales data are synthetic; real
German automotive-market and calendar context are used where useful. The
core business problem is forecasting German WKR sales and product mix
under changing automotive production, registrations and drivetrain mix.

The analytical/forecasting baseline is now complete enough to freeze as
the workload for the engineering curriculum. It has been executed
successfully as an Azure Machine Learning command job directly from
version-controlled GitHub definitions.

The main chain achieved so far is:

``` text
business problem
→ synthetic but realistic data-generating process
→ analytical forecast design
→ Python production-oriented forecast pipeline
→ GitHub source of truth
→ declarative Azure ML YAML
→ Azure compute
→ successful cloud execution
→ persisted forecast + diagnostics
→ technical/statistical/business acceptance
```

The next learning layer is **CI/CD**, beginning conceptually rather than
by blindly adding YAML. Docker, Kubernetes, APIs, monitoring,
RAG/evaluation, MCP/agents and practical PyTorch come later.

AWS is intentionally deferred. The same workload may later be moved to
AWS for a controlled comparison of developer experience, but there is no
need to duplicate the Azure work before the production-engineering
concepts are learned.

------------------------------------------------------------------------

## 2. Learner / project-owner background

The project owner is a senior quantitative/data-science professional
rather than a beginner programmer or junior analyst.

Relevant background supplied during the project:

-   PhD in Marketing.
-   More than 20 years of analytics and data-driven decision-support
    experience.
-   Very strong statistics/econometrics background.
-   More than 100 Marketing Mix Modeling projects.
-   Strong R, Python, SQL, machine-learning and GenAI experience.
-   Professional background includes Data Scientist work at Nestlé.
-   Member of the winning team in the Nestlé Global ML Challenge 2023.
-   Strong experience translating quantitative work into
    business/stakeholder decisions.
-   Familiar with distributed-computing concepts.
-   Feature engineering is considered a major source of model value.
-   Classical modeling, econometrics, routine Python and standard
    statistical reasoning are not the learning bottleneck.

The broader professional motivation is career development toward
companies and roles with a stronger AI/ML engineering component,
including interest in organizations such as **NVIDIA**. The objective is
not to manufacture a checklist of technologies for a CV. The objective
is to close genuine engineering knowledge gaps through hands-on work
until the technologies can be discussed and used with credible
understanding.

Implication for teaching style:

> Do not spend project time reteaching statistics, generic Python, basic
> ML, distributed-computing basics or obvious modeling workflow. Spend
> explanatory depth on engineering layers that are genuinely new.

The project should produce both real understanding and a credible
technical portfolio/repository.

------------------------------------------------------------------------

## 3. Learning philosophy

The project deliberately avoids "skill bingo" such as:

``` text
tiny Docker demo
tiny Kubernetes demo
tiny RAG demo
tiny API demo
```

Instead:

``` text
one serious WKR workload
→ reproducibility
→ cloud execution
→ CI/CD
→ containers
→ orchestration/scaling
→ serving
→ monitoring
→ RAG/evaluation
→ MCP/agents
```

The workload should remain recognizably the same while its engineering
maturity increases.

### Teaching/interaction preference

For familiar analytical layers: - move quickly; - do not force code
review for routine forecast/model code; - provide compact diagnostics
and business interpretation; - avoid reopening settled modeling choices
without evidence of a problem.

For new engineering layers: - slow down; - explain the mental model
first; - explain terminology and why the layer exists; - explain what
practical problem it solves now and later; - implement one small
piece; - observe the result; - only then add the next layer.

The user explicitly does **not** want to become an operator who merely
follows commands supplied by ChatGPT. The goal is understanding
sufficient to reconstruct and reason about the architecture
independently.

A useful pattern established for YAML was:

``` text
concept
→ mental model/metaphor
→ small concrete file
→ line-by-line interpretation
→ execute
→ inspect actual behavior
```

Use the same pattern for CI/CD, Docker, Kubernetes, APIs,
identity/security and related topics.

------------------------------------------------------------------------

## 4. Working conventions

### Repository and artifacts

-   GitHub is the **source of truth**.
-   Azure is an **execution environment**, not an interactive
    source-code editor.
-   Do not repair production code interactively inside Azure.
-   After a failure: identify the failing layer → fix
    source/data/definition in GitHub → commit → `git pull` → rerun.
-   Prefer repository-ready complete files over patches/snippet salad.
-   Use stable filenames; avoid arbitrary version suffixes.
-   When an R file is created or changed, provide the **complete current
    R file** as a downloadable artifact.
-   Apply the same full-file principle to Python, YAML, GitHub Actions
    and documentation when practical.
-   Use relative project paths.
-   Do not introduce `setwd()` into new/refactored R code.
-   Synthetic generators use fixed seeds.
-   Validate inputs and outputs and fail clearly.

### Azure operation

-   Prefer Azure CLI + YAML + source control over GUI configuration.
-   Cloud Shell commands should be complete **single-line copy/paste
    commands**.
-   Do not invent Azure run IDs or resource names.
-   Separate technical completion from business/model acceptance:
    -   `Completed` means the job executed technically.
    -   It does not by itself mean the result is acceptable.

### Modeling

The forecasting workload is now a baseline, not an invitation to endless
model optimization.

Do not restart residual archaeology or reopen AR-term decisions unless a
concrete future requirement makes it necessary.

------------------------------------------------------------------------

## 5. Fictional company and business problem

### Company

**WKR Komponenten KGaA**

Fictional Hessen-based German global automotive supplier specializing in
elastomer and rubber-to-metal components.

Approximate project scale:

-   German sales: roughly EUR 300--350m/year.
-   2024 German sales anchor: approximately EUR 330m.
-   Global revenue: approximately EUR 1bn.

All WKR-specific sales/product/company data are synthetic and should
remain clearly labeled as such in public documentation.

### Product segments

  Segment                 Products
  ------------------- ------------
  Sealing                    6,200
  Cable Protection           3,100
  Chassis NVH                4,800
  Powertrain Mounts          3,600
  Hoses & Bellows            4,100
  Other Automotive           2,200
  **Total**             **24,000**

### Business question

> How will German WKR sales and product mix develop over the next 6--18
> months under scenarios for new registrations, drivetrain mix, German
> vehicle production, and energy/fuel prices?

### Core causal/business logic

``` text
economic environment → vehicle demand → German vehicle production → WKR OE sales
vehicle stock / age → replacement demand
drivetrain mix → segment-specific content effects
competition → WKR share → sales
calendar / shutdowns / working patterns → production and delivery timing → daily WKR sales
```

Daily granularity is intentional because weekday structure, holidays,
shutdowns, persistence and lag behavior are meaningful. Monthly external
variables may be held constant within a month.

------------------------------------------------------------------------

## 6. Data model and repository

### Core tables

1.  `product_master`
2.  `sales_daily_de`
3.  `automotive_market_de`
4.  energy variables planned/later as needed

### Daily sales grain

Period:

``` text
2022-01-01 through 2026-12-31
```

Six segments × 1,826 days = **10,956 rows** in the complete generated
daily panel.

### Repository structure

``` text
wkr-automotive-forecasting-lab/
├── README.md
├── .gitignore
├── R/
│   ├── generate_product_master.R
│   ├── generate_sales_daily_de.R
│   ├── forecast_automotive_market_de.R
│   └── model_powertrain_mounts.R
├── src/wkr_pipeline/
│   ├── calendar_pipeline.py
│   └── sales_forecast_pipeline.py
├── tests/
│   ├── test_calendar_pipeline.py
│   └── test_sales_forecast_pipeline.py
├── azureml/
│   ├── environment.yml
│   ├── calendar_job.yml
│   ├── sales_forecast_environment.yml
│   └── sales_forecast_job.yml
├── data/
│   ├── master/
│   ├── raw/
│   ├── sales/
│   └── forecast/
└── docs/
    ├── architecture.md
    ├── data_contract.md
    ├── run-github-code-on-azure-ml.md
    ├── project_status.md
    └── decisions/
        ├── 0003-first-azure-ml-job.md
        └── 0004-first-cloud-sales-forecast.md
```

------------------------------------------------------------------------

## 7. Product-master generator

File: `R/generate_product_master.R`

Important characteristics:

-   fixed seed: `set.seed(20260918)`;
-   24,000 products;
-   segment-specific channels;
-   drivetrain relevance;
-   lifecycle months;
-   output: `data/master/product_master.csv`.

The product master supports segment-specific exposure to BEV/non-BEV
market changes.

------------------------------------------------------------------------

## 8. Calendar data and calendar pipeline

### Legacy/raw calendar

File: `data/raw/datumlanderferienfeiertage.csv`

Properties: - 21,199 rows in the legacy file; - semicolon separated; -
UTF-8 BOM; - Bundesland-level observations.

Columns:

``` text
Datum, Bundesland, Ferien, Karfreitag, Weihnachten, Silvester,
ErsterMai, Pfingsten, Himmelfahrt
```

States:

``` text
Berlin, Brandenburg, Bremen, Niedersachsen, Nordrhein-Westfalen,
Sachsen-Anhalt, Thüringen
```

The holiday columns are research-derived **timing variables**, not
merely boolean flags indicating that a date is a holiday. Some logic
historically originated in FMCG work, including pre-holiday timing
effects. For WKR B2B usage, the calendar should represent
production/work/delivery timing.

Longer-term architecture should distinguish:

``` text
raw calendar events → derived business timing features
```

### Encoding note

The CSV contains the Unicode string `Thüringen`. Some earlier R files
used `Thueringen` because of locale/encoding friction. The Python
pipeline reads with `encoding="utf-8-sig"` and can preserve Unicode.

An explicit encoding/data-contract test may be useful later, but it is
not a current blocker.

### Calendar Python pipeline

Main file: `src/wkr_pipeline/calendar_pipeline.py`

Conceptual flow:

``` text
OpenHolidays API
→ fetch events
→ expand dates/states
→ derive legacy-compatible timing features
→ validate
→ calendar output + comparison diagnostics
```

KMK is treated as authoritative validation/reference context;
OpenHolidays was used as a convenient API source.

### First successful Azure ML run

Azure resources:

``` text
Resource group: rg-wkr-ml
Workspace:      mrw-wkr-forecasting
Region:         Poland Central
Compute:        cpu-cluster
```

West Europe had failed for new-resource allocation, so Poland Central
was used.

Successful calendar job:

``` text
Run ID: coral_pear_6pll5ty44w
Status: Completed
```

Comparison results:

``` json
{
  "generated_rows": 21443,
  "legacy_rows": 21199,
  "common_rows": 21181,
  "Ferien": {"matches":20714,"mismatches":467,"match_rate":0.9779519380576932},
  "Karfreitag":{"matches":21181,"mismatches":0,"match_rate":1.0},
  "Weihnachten":{"matches":21139,"mismatches":42,"match_rate":0.9980170907889145},
  "Silvester":{"matches":21181,"mismatches":0,"match_rate":1.0},
  "ErsterMai":{"matches":21181,"mismatches":0,"match_rate":1.0},
  "Pfingsten":{"matches":21181,"mismatches":0,"match_rate":1.0},
  "Himmelfahrt":{"matches":21181,"mismatches":0,"match_rate":1.0},
  "legacy_only_rows":18,
  "generated_only_rows":262
}
```

Milestone demonstrated:

``` text
GitHub → declarative Azure ML YAML → Azure compute → Python
→ persisted named outputs → Azure run metadata → Completed
```

Decision record: `docs/decisions/0003-first-azure-ml-job.md`

Runbook: `docs/run-github-code-on-azure-ml.md`

------------------------------------------------------------------------

## 9. Synthetic daily sales DGP

File: `R/generate_sales_daily_de.R`

Important characteristics:

-   base R;
-   reads product master, calendar and automotive market;
-   requires `registrations_bev`;
-   uses BEV share and segment product-master drivetrain relevance;
-   2024 German sales target approximately EUR 330m;
-   production response substantial for OE and weak for replacement;
-   BEV factor applied to OE only;
-   full daily calendar;
-   weekday/weekend/shutdown structure;
-   latent AR-like noise;
-   output: `data/sales/sales_daily_de.csv`.

### Regional weights used in the R DGP

``` text
Niedersachsen         0.30
Nordrhein-Westfalen   0.20
Brandenburg           0.12
Sachsen-Anhalt        0.12
Thüringen             0.12
Berlin                0.08
Bremen                0.06
```

Niedersachsen is deliberately weighted more heavily because of the
automotive/VW footprint.

### BEV treatment

The v1 design uses **BEV vs Non-BEV**, not a full ICE/HEV/PHEV/BEV
taxonomy.

`ice_relevance` serves as a proxy for non-BEV content. The BEV factor is
normalized to the 2024 average BEV share and applied to OE only.

------------------------------------------------------------------------

## 10. Automotive-market forecast

The v1 external automotive forecast is frozen for the current baseline.

File: `data/forecast/automotive_market_de_forecast_2026.csv`

  -------------------------------------------------------------------------
  Month               German           Total             BEV      BEV share
                  production   registrations   registrations 
  ----------- -------------- --------------- --------------- --------------
  Sep 2026           413,929         233,506          79,634         34.10%

  Oct 2026           369,965         239,912          85,935         35.82%

  Nov 2026           433,069         258,922          97,284         37.57%

  Dec 2026           289,797         267,980         105,475         39.36%
  -------------------------------------------------------------------------

Do not casually change this data vintage while comparing engineering
implementations.

------------------------------------------------------------------------

## 11. Forecast modeling decisions already settled

Agreed v1 design:

``` text
target grain: daily
models:       separate model per segment
training:     2022-01-01 to 2025-12-31
holdout:      2026-01-01 to 2026-08-31
forecast:     2026-09-01 to 2026-12-31
```

### Autoregression decision

AR terms are **not** in the final v1 forecast specification.

Earlier work found that apparent one-step/in-sample improvements from
autoregressive terms did not translate into sufficient recursive holdout
gains; AR7 was worse in the relevant evaluation.

This is a settled modeling decision for the baseline. Do not reintroduce
AR terms merely because residual diagnostics show autocorrelation.

### Required diagnostics

The Python/Azure implementation should surface:

-   MAE;
-   RMSE;
-   MAPE;
-   bias;
-   Durbin-Watson;
-   residual ACF, especially lags 1 and 7, with 14/30 also useful;
-   Ljung-Box;
-   Q-Q plot;
-   actual vs predicted plot.

------------------------------------------------------------------------

## 12. Python sales-forecast pipeline

Main file: `src/wkr_pipeline/sales_forecast_pipeline.py`

The cloud job deliberately runs the existing R DGP first and then
Python:

``` text
R/generate_sales_daily_de.R
→ synthetic daily sales
→ Python validation + feature engineering
→ six segment-level daily models
→ Jan-Aug 2026 holdout
→ diagnostics
→ refit through Aug 2026
→ Sep-Dec 2026 forecast
```

Reason: do not duplicate the synthetic DGP in Python and create two
competing definitions of truth. R remains the analytical/DGP reference;
Python is the production/cloud-engineering layer.

### Python model specification

``` text
log(1 + daily net sales)
~ C(weekday)
+ holiday_intensity
+ school_holiday_intensity
+ summer_shutdown
+ year_end_shutdown
+ log_production
+ bev_share_pp
```

No AR terms.

### Forecast outputs

``` text
sales_forecast_daily_2026_sep_dec.csv
sales_forecast_monthly_2026_sep_dec.csv
sales_forecast_total_monthly_2026_sep_dec.csv
sales_forecast_diagnostics.json
plots/
```

Plots include actual-vs-predicted, residual ACF and residual Q-Q
diagnostics.

### Environment

File: `azureml/sales_forecast_environment.yml`

``` yaml
name: wkr-sales-forecast
channels:
  - conda-forge
dependencies:
  - python=3.11
  - r-base=4.3
  - numpy
  - pandas
  - scipy
  - statsmodels
  - matplotlib
```

The current environment is intentionally not yet hardened with exact
package pins. Dependency hardening/containerization is a future
engineering lesson.

### Azure job

File: `azureml/sales_forecast_job.yml`

``` yaml
$schema: https://azuremlschemas.azureedge.net/latest/commandJob.schema.json
display_name: wkr-sales-forecast
experiment_name: wkr-sales-forecast
code: ..
command: >-
  Rscript R/generate_sales_daily_de.R &&
  python src/wkr_pipeline/sales_forecast_pipeline.py
  --sales data/sales/sales_daily_de.csv
  --calendar ${{inputs.calendar}}
  --market ${{inputs.market}}
  --market-forecast ${{inputs.market_forecast}}
  --output-dir ${{outputs.forecast}}
inputs:
  calendar:
    type: uri_file
    path: ../data/raw/datumlanderferienfeiertage.csv
  market:
    type: uri_file
    path: ../data/raw/automotive_market_de.csv
  market_forecast:
    type: uri_file
    path: ../data/forecast/automotive_market_de_forecast_2026.csv
outputs:
  forecast:
    type: uri_folder
environment:
  image: mcr.microsoft.com/azureml/openmpi4.1.0-ubuntu22.04
  conda_file: sales_forecast_environment.yml
compute: azureml:cpu-cluster
```

------------------------------------------------------------------------

## 13. First sales-forecast Azure failure: useful engineering incident

First sales-forecast run:

``` text
Run ID: teal_guitar_58q23drsb5
```

It failed in the **R generator**, not Python:

``` text
Error: Missing automotive market columns: registrations_bev
Execution halted
```

The repository version of `data/raw/automotive_market_de.csv` lacked the
field required by the existing R generator.

The source data were corrected in GitHub rather than patched in Azure.

Corrected schema:

``` text
month, vehicle_production_de, registrations_total_de, registrations_bev, data_status
```

BEV aggregate integrity checks used:

``` text
2022          470,559
2023          524,219
2024          380,609
2025          545,142
2026 Jan-Aug  515,545
```

The correction deliberately added the missing BEV field without silently
changing production or total-registration values.

Cloud Shell then performed `git pull`, moving the checkout from
`e14ca07` to `d7e26a2`.

This incident is an important example:

``` text
failure → identify layer → correct source of truth → commit → pull → rerun
```

------------------------------------------------------------------------

## 14. Successful Azure sales forecast

Successful rerun:

``` text
Run ID:       amiable_carrot_10g1wp89q4
Experiment:   wkr-sales-forecast
Status:       Completed
```

### Business/output checks

``` text
segments_forecast:               6
daily_forecast_rows:           732
negative_forecasts:              0
missing_forecasts:               0
forecast_total_sep_dec_eur: 111,894,016.12
```

### Holdout metrics

  Segment               MAE EUR   RMSE EUR     MAPE   Bias vs mean actual
  ------------------- --------- ---------- -------- ---------------------
  Sealing                18,260     27,426   13.88%                -4.47%
  Cable Protection       13,426     18,958   16.24%                -8.49%
  Chassis NVH            18,101     27,853   11.06%                -4.21%
  Powertrain Mounts      15,091     24,147   10.73%                -1.09%
  Hoses & Bellows        14,431     21,304   10.32%                -3.94%
  Other Automotive        7,195     10,524   12.91%                -3.22%

### Residual diagnostics

  Segment               Durbin-Watson   ACF(1)   ACF(7)
  ------------------- --------------- -------- --------
  Sealing                       1.250    0.374    0.263
  Cable Protection              1.248    0.375    0.243
  Chassis NVH                   1.244    0.378    0.257
  Powertrain Mounts             1.260    0.369    0.267
  Hoses & Bellows               1.232    0.383    0.245
  Other Automotive              1.274    0.362    0.239

Ljung-Box p-values at the reported lags are extremely small (roughly
`10^-55` to `10^-69`), so residual independence is clearly rejected.

Interpretation: - positive short-term residual persistence remains; -
weekly structure remains; - this is explicitly documented; - it is
**not** a reason to reopen the settled recursive AR decision without a
new business requirement.

### Structural effects

Holdout-model production elasticities:

``` text
Sealing               0.544
Cable Protection      0.686
Chassis NVH           0.380
Powertrain Mounts     0.342
Hoses & Bellows       0.386
Other Automotive      0.524
```

Powertrain Mounts holdout:

``` text
production elasticity       0.342
BEV +10 percentage points  -6.02%
```

Final refit through August 2026:

``` text
production elasticity       0.370
BEV +10 percentage points  -6.05%
```

Smaller BEV effects in less drivetrain-sensitive segments should not be
overinterpreted; some change sign after refitting and are better treated
as small effects around zero.

### Accepted monthly forecast

  Month                Forecast net sales
  ------------------ --------------------
  September 2026               EUR 31.85m
  October 2026                 EUR 27.08m
  November 2026                EUR 31.31m
  December 2026                EUR 21.65m
  **Sep-Dec 2026**        **EUR 111.89m**

Exact values:

``` text
2026-09-01   31,851,586.08
2026-10-01   27,082,753.70
2026-11-01   31,312,649.54
2026-12-01   21,647,026.81
```

The December decline is consistent with the lower December
German-production forecast and year-end shutdown/calendar structure.

### Acceptance decision

The Azure Sales Forecast v1 is accepted as the stable forecasting
baseline for the next engineering phase.

Decision record: `docs/decisions/0004-first-cloud-sales-forecast.md`

Do not turn the next project phase back into a forecasting seminar
unless the forecast genuinely blocks an engineering objective.

------------------------------------------------------------------------

## 15. Known implementation differences / future diagnostic notes

These are worth remembering if a later comparison produces unexpected
results.

### Calendar weighting

The Python forecast implementation has used a simpler dynamic state
weighting in which Niedersachsen receives extra weight and other states
receive generic weights, while the R DGP uses the explicit regional
weights listed earlier.

This is not currently a blocker. If future holdout behavior unexpectedly
diverges from the R reference, inspect this.

### Shutdown feature definitions

The Python calendar feature construction has used broad definitions
approximately equivalent to:

``` text
summer shutdown: July/August
year-end shutdown: Dec 20-31
```

The DGP uses more specific timing approximately:

``` text
summer: Jul 20-Aug 15
year-end: Dec 23-Jan 2
```

Do not change this merely for theoretical tidiness. Investigate only if
it matters for a concrete requirement.

------------------------------------------------------------------------

## 16. Azure mental model established so far

### YAML

YAML is structured data, not an Azure programming language.

Historically "Yet Another Markup Language", later "YAML Ain't Markup
Language".

In this project:

``` text
Python/R = how to calculate
YAML     = under what conditions and with what resources/code/inputs/outputs to execute
```

Azure ML YAML is like a **production order / work order**.

`az ml job create --file ...` means conceptually:

> Here is the version-controlled work order. Execute it.

### Current execution architecture

``` text
GitHub
↓
Azure Cloud Shell / CLI
↓
Azure ML YAML
↓
workspace
↓
compute
↓
environment
↓
code
↓
named outputs
↓
technical + business validation
```

Azure resources:

``` text
Resource group: rg-wkr-ml
Workspace:      mrw-wkr-forecasting
Region:         Poland Central
Compute:        cpu-cluster
```

------------------------------------------------------------------------

## 17. Current conceptual frontier: CI/CD

This is the exact point at which the previous conversation intentionally
stopped.

A first draft `.github/workflows/ci.yml` had been created, but the user
explicitly asked to pause before simply installing it.

Reason:

> For new engineering areas, understand what is being built, why it
> exists, and what it will provide now and later before executing
> instructions.

### CI mental model already introduced

**CI = Continuous Integration**

Central idea:

> Every relevant repository change is automatically checked when it is
> integrated with the shared codebase.

Instead of:

``` text
Alexander remembers to run tests
```

the process should enforce:

``` text
change
↓
automatic clean environment
↓
tests / validation
↓
objective pass/fail result attached to the change
```

"Continuous" means checks happen repeatedly as changes are integrated,
not that a machine necessarily runs continuously.

### CD terminology

CD may mean:

1.  **Continuous Delivery** --- automatically reach a deployable state;
    a human may still approve/trigger production deployment.
2.  **Continuous Deployment** --- a sufficiently validated change is
    automatically deployed without a manual production step.

For WKR, begin with **Continuous Delivery** thinking rather than
immediately automating production deployment.

### Key distinction

``` text
CI asks:
Is this version technically trustworthy?

CD asks:
How does a trustworthy version move safely into its target environment?
```

### GitHub Actions

GitHub Actions is an implementation tool for CI/CD, not the concept
itself. Concepts transfer to Azure DevOps Pipelines, GitLab CI/CD,
Jenkins, CircleCI, etc.

### GitHub Actions vocabulary

``` text
EVENT
  ↓
WORKFLOW
  ↓
JOB
  ↓
STEP
```

Example:

``` text
push/PR → WKR CI → test job → checkout / setup / install / pytest
```

### Runner

A **runner** is the machine that executes a GitHub Actions job.

`runs-on: ubuntu-22.04` means conceptually:

> GitHub, provide a fresh Ubuntu machine for this job.

Useful principle:

> "Works on my machine" becomes "prove it on a clean machine."

### Why CI matters specifically for WKR

The project already contains R, Python, tests, Azure YAML, data
contracts and documentation. A code change can silently break a forecast
horizon, expected segment set, input contract, YAML definition or
dependency.

Tests currently exist, but without CI they are passive.

**CI turns tests into an active rule of the development process.**

### Long-term CI/CD evolution

Possible future PR pipeline:

``` text
Pull Request
→ unit tests
→ data-contract tests
→ linting/static checks
→ Azure YAML validation
→ container build
→ security checks
→ integration tests
→ merge allowed
```

After merge:

``` text
main
→ build Docker image
→ tag image with Git commit SHA
→ push to registry
→ deploy to staging
→ smoke/integration tests
→ human approval
→ production
```

ML-specific gates may later include:

``` text
forecast produced?
no NaNs?
no negative forecasts?
expected segments present?
accuracy within agreed tolerance?
business totals plausible?
```

This is where existing statistical expertise becomes encoded as
automated engineering controls.

### CI/CD and MLOps are not identical

Traditional CI/CD handles changing software.

ML systems additionally have:

``` text
changing code + changing data + changing models + changing predictive quality
```

MLOps therefore adds data/model quality controls to normal software
CI/CD.

### First proposed CI workflow

A simple first workflow was drafted to: - trigger on push/PR to
`main`; - use `ubuntu-22.04`; - check out the repository; - set up
Python 3.11; - install
`numpy pandas scipy statsmodels matplotlib pytest`; - execute
`python -m pytest -q`.

**Do not blindly upload it at the start of the next conversation.**

Resume by reinforcing the conceptual model, then decide together exactly
what the first CI workflow should prove.

Azure should initially remain outside CI:

``` text
GitHub change → GitHub-hosted runner → tests → pass/fail
```

Only after this is understood should GitHub Actions authenticate to
Azure.

------------------------------------------------------------------------

## 18. Future Azure/GitHub identity lesson

When GitHub Actions eventually submits Azure jobs, a new engineering
problem appears:

> How can Azure know that a GitHub workflow is allowed to act without
> storing the user's personal password?

This should become a deliberate lesson covering: - identity; -
authentication; - authorization; - machine/workload identity; -
secrets; - least privilege; - trust between GitHub and Azure.

Do not simply paste personal credentials into GitHub.

Conceptual transition:

``` text
today:
human → az ml job create → Azure

later:
GitHub Actions workload identity → authorized Azure action → Azure
```

------------------------------------------------------------------------

## 19. Planned engineering curriculum

### Completed / sufficiently established

1.  Reproducible forecasting workload.
2.  GitHub source-of-truth workflow.
3.  Azure ML command jobs.
4.  Named cloud artifacts and run diagnostics.
5.  Basic cloud failure/debug/rerun discipline.

### Next

6.  **CI/CD**
    -   concepts;
    -   GitHub Actions;
    -   runners;
    -   events/workflows/jobs/steps;
    -   PR quality gates;
    -   Azure authentication;
    -   controlled delivery.
7.  **Docker**
    -   image vs container;
    -   Dockerfile;
    -   build context;
    -   layers/cache;
    -   dependency/environment reproducibility;
    -   local/cloud parity;
    -   registry;
    -   tagging/versioning.
8.  **Kubernetes / AKS**
    -   why orchestration exists;
    -   pods;
    -   deployments;
    -   services;
    -   configuration/secrets;
    -   scaling;
    -   health checks;
    -   rollout/rollback;
    -   when Kubernetes is justified and when it is not.
9.  **Forecast API / serving**
    -   request/response contract;
    -   likely FastAPI or equivalent;
    -   batch vs online inference;
    -   model/service boundaries;
    -   API versioning;
    -   latency/reliability concerns.
10. **Monitoring**
    -   infrastructure/service health;
    -   logs/metrics/traces;
    -   data quality;
    -   forecast/model performance;
    -   drift;
    -   business KPIs;
    -   alerting.
11. **RAG + evaluation**
    -   WKR-relevant knowledge layer rather than toy chatbot;
    -   retrieval architecture;
    -   chunking/indexing;
    -   evaluation;
    -   grounding/citations;
    -   failure modes.
12. **MCP / agents**
    -   tools and permissions;
    -   agent boundaries;
    -   interaction with WKR data/services;
    -   evaluation and safety;
    -   avoid "agent" demos without a real workflow.
13. **Practical PyTorch**
    -   only where it adds learning value;
    -   do not replace adequate classical models merely to use a neural
        network.
14. **Kubeflow**
    -   later and only if it solves a real orchestration/MLOps learning
        objective.

### AWS later

For a controlled future comparison preserve:

``` text
same Git commit
same Python/R code
same inputs
same outputs
same business task
```

Compare developer/operational experience rather than feature-list
marketing or tiny cost differences.

------------------------------------------------------------------------

## 20. What not to do next

-   **Do not restart modeling.** The current forecast is adequate as an
    engineering workload.
-   **Do not turn the project into disconnected tutorials.** Every
    technology should attach to WKR.
-   **Do not paste large configuration files without explanation.** At
    new layers, understanding is the deliverable.
-   **Do not overuse Azure GUI.** Durable system definitions should be
    version-controlled.
-   **Do not store generated cloud artifacts in GitHub by default.**
-   **Do not equate job success with model acceptance.**
-   **Do not introduce AWS yet.**

------------------------------------------------------------------------

## 21. Recommended continuation in the next chat

Start approximately here:

> WKR Forecasting v1 and the first Azure cloud execution are complete
> and accepted. The next learning layer is CI/CD. Before editing
> `.github/workflows/ci.yml`, continue the conceptual explanation until
> the user understands why CI exists, what a runner is, what a
> workflow/job/step is, and what should happen on a pull request versus
> a merge to `main`.

Good next sequence:

``` text
1. recap CI vs Continuous Delivery vs Continuous Deployment
2. distinguish GitHub Actions from CI/CD as a concept
3. design desired WKR development lifecycle on paper
4. decide which event should trigger which checks
5. inspect the minimal ci.yml
6. commit it
7. watch the first GitHub-hosted runner execute
8. inspect logs/results
9. introduce pull requests / branch protection conceptually
10. only then connect GitHub Actions to Azure
```

Do not jump directly to Azure authentication.

------------------------------------------------------------------------

## 22. Desired target architecture over time

``` text
GitHub: code / tests / config
          ↓ commit/PR
GitHub Actions: tests / validation / CI
          ↓ trusted artifact
build / container registry
          ↓
   ┌──────┴────────┐
   ↓               ↓
Azure ML       Forecast API/service
batch jobs          │
   └──────┬─────────┘
          ↓
monitoring / quality
          ↓
RAG / tools / agents
```

This is a direction, not a requirement to use every technology. Each
component must earn its place.

------------------------------------------------------------------------

## 23. Portfolio / career perspective

The project should ultimately demonstrate more than "knows Azure" or
"knows Kubernetes."

The stronger story is:

> A senior quantitative scientist took a realistic forecasting problem
> from analytical design through reproducible data generation,
> validation and cloud execution, then progressively engineered it into
> an automated, containerized, observable and AI-integrated production
> system.

That combines existing strengths: - statistical depth; - causal/business
reasoning; - feature engineering; - forecasting; - stakeholder
relevance;

with deliberately acquired engineering depth: - reproducibility; -
source-controlled infrastructure/job definitions; - cloud compute; -
CI/CD; - containerization; - orchestration; - serving; - monitoring; -
modern GenAI/RAG/tool integration.

For applications to technically demanding AI/ML organizations such as
NVIDIA, the objective is not to pretend that the project owner has spent
ten years as a platform engineer. The credible proposition is:

> deep quantitative expertise plus demonstrated ability to learn, build
> and reason across the modern ML/AI engineering stack.

Favor technical substance and explainable architectural choices over
buzzword accumulation.

------------------------------------------------------------------------

## 24. Communication style for future ChatGPT sessions

Default language: **German**.

Preferred interaction: - direct; - technically serious; - intellectually
challenging; - concise where the topic is familiar; - detailed where the
engineering concept is new; - occasional humor welcome; - no patronizing
beginner tone; - no generic best-practices dump without connection to
WKR.

Treat the user as a senior quantitative expert learning adjacent
engineering disciplines.

Do not repeatedly explain basic regression, basic Python, elementary
statistics or basic distributed-computing concepts.

Do explain carefully: - cloud execution models; - CI/CD; -
identity/authentication/authorization; - containers; - Kubernetes; -
service architecture; - observability; - production ML/AI design; - RAG
evaluation; - MCP/agent tool architecture.

When commands are required, especially Azure Cloud Shell, provide
complete one-line commands.

When a failure occurs, reason explicitly about **which layer failed**:

``` text
source/data?
test?
dependency?
runner?
YAML?
authentication?
Azure control plane?
environment build?
compute?
application runtime?
output contract?
business validation?
```

------------------------------------------------------------------------

## 25. Key milestone summary

### Milestone 1 --- analytical WKR workload

Completed: - fictional company/business model; - product master; -
synthetic daily sales; - automotive-market drivers; - calendar logic; -
segment forecast design; - holdout methodology.

### Milestone 2 --- cloud calendar pipeline

Completed: - Python calendar pipeline; - tests; - Azure environment/job
YAML; - first successful GitHub → Azure ML execution; - persisted
comparison artifacts; - ADR/runbook.

Run: `coral_pear_6pll5ty44w`

### Milestone 3 --- cloud sales forecast

Completed: - Python six-segment forecast pipeline; - classical residual
diagnostics; - Azure environment/job; - first failed run revealing a
genuine data-contract issue; - GitHub correction; - successful rerun; -
forecast acceptance; - ADR + README update.

Successful run: `amiable_carrot_10g1wp89q4`

Accepted Sep-Dec forecast: **EUR 111.89m**

### Milestone 4 --- productionization

**Current status: about to begin.**

First topic: **CI/CD**

Do not skip the conceptual foundation.

------------------------------------------------------------------------

## 26. One-sentence handover

**Continue the WKR project from an accepted Azure-executed forecasting
baseline into production engineering, beginning with a concept-first
treatment of CI/CD and GitHub Actions, while preserving GitHub as source
of truth and using the existing WKR workload as the single learning
vehicle for every subsequent engineering layer.**
