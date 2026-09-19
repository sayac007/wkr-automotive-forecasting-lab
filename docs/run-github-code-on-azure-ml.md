# Running WKR GitHub Code on Azure Machine Learning via Cloud Shell

This document records the minimal, reproducible workflow used on 2026-09-19 to execute the WKR calendar pipeline from GitHub on Azure Machine Learning, inspect the run, download the artifacts, and validate the output.

The purpose is not to document every Azure Portal click. The useful pattern is:

**GitHub repository → Azure Cloud Shell → Azure ML YAML job → compute cluster → persisted outputs → validation**

The Azure Portal is used mainly to create the initial Azure resources. The actual ML job is then submitted declaratively from the repository.

---

## 1. One-time Azure setup

The following Azure resources must already exist:

- an Azure subscription
- a resource group
- an Azure Machine Learning workspace
- an Azure ML compute cluster

For the WKR project, the first successful run used:

```text
Resource group: rg-wkr-ml
Azure ML workspace: mrw-wkr-forecasting
Region: Poland Central
Compute cluster: cpu-cluster
```

The compute cluster was configured as a small CPU cluster with:

```text
Minimum nodes: 0
Maximum nodes: 1
```

This keeps idle compute cost at zero while allowing Azure ML to provision a node when a job is submitted.

The repository already contains the Azure ML definitions:

```text
azureml/
├── calendar_job.yml
└── environment.yml
```

and the Python implementation:

```text
src/wkr_pipeline/calendar_pipeline.py
```

---

## 2. Open Azure Cloud Shell

Open Azure Cloud Shell from the Azure Portal and use **Bash**.

For this workflow, persistent Cloud Shell storage is not required. The shell can be treated as disposable because the source of truth remains GitHub.

Check that the Azure ML CLI extension is available:

```bash
az extension add -n ml
```

If Azure reports that the extension is already installed, continue.

Example from the first WKR run:

```text
Extension 'ml' 2.44.1 is already installed.
```

---

## 3. Clone the GitHub repository

Clone the public repository directly into Cloud Shell:

```bash
git clone https://github.com/sayac007/wkr-automotive-forecasting-lab.git
cd wkr-automotive-forecasting-lab
```

Optional sanity check:

```bash
ls
```

The repository root should contain the project directories, including:

```text
R
azureml
data
docs
src
tests
README.md
```

The important principle is that no application code is edited inside Azure. Azure receives the versioned repository state.

---

## 4. Inspect the Azure ML job definition

Before submitting the job, inspect the YAML:

```bash
cat azureml/calendar_job.yml
```

For the first WKR calendar run, the job definition was:

```yaml
$schema: https://azuremlschemas.azureedge.net/latest/commandJob.schema.json
display_name: wkr-calendar-pipeline
experiment_name: wkr-calendar
code: ..
command: >-
  python src/wkr_pipeline/calendar_pipeline.py
  --start-year 2017
  --end-year 2026
  --legacy ${{inputs.legacy_calendar}}
  --output ${{outputs.calendar}}/datumlanderferienfeiertage.csv
  --comparison-dir ${{outputs.comparison}}
inputs:
  legacy_calendar:
    type: uri_file
    path: ../data/raw/datumlanderferienfeiertage.csv
outputs:
  calendar:
    type: uri_folder
  comparison:
    type: uri_folder
environment:
  image: mcr.microsoft.com/azureml/openmpi4.1.0-ubuntu22.04
  conda_file: environment.yml
compute: azureml:cpu-cluster
```

Conceptually, this file is the execution contract:

```text
code         → which repository content Azure uploads
command      → which process Azure starts
environment  → which runtime and dependencies are created
compute      → where the process runs
inputs       → what data is mounted into the job
outputs      → which result locations Azure persists
```

---

## 5. Submit the Azure ML job

From the repository root, submit the YAML job:

```bash
az ml job create   --file azureml/calendar_job.yml   --resource-group rg-wkr-ml   --workspace-name mrw-wkr-forecasting
```

Azure ML then:

1. validates the YAML,
2. uploads the code snapshot,
3. uploads or registers the input,
4. creates the declared environment,
5. binds the job to `cpu-cluster`,
6. starts the job,
7. persists logs and named outputs.

The first successful WKR job received the Azure ML run name:

```text
coral_pear_6pll5ty44w
```

Azure also recorded the Git metadata automatically, including:

```text
branch: main
commit: 6e5fb77da2f35b5b186fb953e82f6a2cbf259915
repository: https://github.com/sayac007/wkr-automotive-forecasting-lab.git
```

This connects a cloud run to a concrete repository state.

---

## 6. Check job status

To check the job without opening Azure ML Studio:

```bash
az ml job show   --name coral_pear_6pll5ty44w   --resource-group rg-wkr-ml   --workspace-name mrw-wkr-forecasting   --query status
```

For a slightly more useful response:

```bash
az ml job show   --name coral_pear_6pll5ty44w   --resource-group rg-wkr-ml   --workspace-name mrw-wkr-forecasting   --query "{status:status,error:error}"
```

The successful run returned:

```json
{
  "error": null,
  "status": "Completed"
}
```

Typical intermediate states include:

```text
Preparing
Running
```

A failed run would return `Failed` and should be debugged from its logs rather than by changing code interactively in Azure.

---

## 7. Stream job logs

To attach the shell to the job logs:

```bash
az ml job stream   --name coral_pear_6pll5ty44w   --resource-group rg-wkr-ml   --workspace-name mrw-wkr-forecasting
```

For copy/paste use, the same command can be entered on one line:

```bash
az ml job stream --name coral_pear_6pll5ty44w --resource-group rg-wkr-ml --workspace-name mrw-wkr-forecasting
```

If the stream contains little or no output, use `az ml job show` to inspect the actual job status.

---

## 8. Download the completed job artifacts

After the job is completed, download all artifacts:

```bash
az ml job download   --name coral_pear_6pll5ty44w   --resource-group rg-wkr-ml   --workspace-name mrw-wkr-forecasting   --all   --download-path ./azure-run
```

Inspect the downloaded files:

```bash
find ./azure-run -type f
```

The first WKR run produced:

```text
./azure-run/named-outputs/comparison/calendar_comparison_mismatches.csv
./azure-run/named-outputs/comparison/calendar_comparison_summary.json
./azure-run/named-outputs/calendar/datumlanderferienfeiertage.csv
./azure-run/artifacts/azureml-logs/20_image_build_log.txt
./azure-run/artifacts/system_logs/...
./azure-run/artifacts/user_logs/std_log.txt
```

The important distinction is:

```text
named-outputs/  → business/data outputs declared by the job
artifacts/      → technical Azure ML logs and execution artifacts
```

---

## 9. Validate the business result

For the calendar pipeline, inspect the comparison summary:

```bash
cat ./azure-run/named-outputs/comparison/calendar_comparison_summary.json
```

The first successful Azure run returned:

```json
{
  "generated_rows": 21443,
  "legacy_rows": 21199,
  "common_rows": 21181,
  "Ferien": {
    "matches": 20714,
    "mismatches": 467,
    "match_rate": 0.9779519380576932
  },
  "Karfreitag": {
    "matches": 21181,
    "mismatches": 0,
    "match_rate": 1.0
  },
  "Weihnachten": {
    "matches": 21139,
    "mismatches": 42,
    "match_rate": 0.9980170907889145
  },
  "Silvester": {
    "matches": 21181,
    "mismatches": 0,
    "match_rate": 1.0
  },
  "ErsterMai": {
    "matches": 21181,
    "mismatches": 0,
    "match_rate": 1.0
  },
  "Pfingsten": {
    "matches": 21181,
    "mismatches": 0,
    "match_rate": 1.0
  },
  "Himmelfahrt": {
    "matches": 21181,
    "mismatches": 0,
    "match_rate": 1.0
  },
  "legacy_only_rows": 18,
  "generated_only_rows": 262
}
```

This is the actual acceptance test.

A job being `Completed` proves only that the process ran without a reported runtime failure. The project considers the cloud run successful only after the produced artifacts are also checked for business plausibility.

For this run:

```text
Ferien        97.7952%
Karfreitag   100.0000%
Weihnachten   99.8017%
Silvester    100.0000%
ErsterMai    100.0000%
Pfingsten    100.0000%
Himmelfahrt  100.0000%
```

The remaining differences are deliberately retained for investigation rather than silently forcing the generated calendar to reproduce every historical legacy value.

---

## 10. What should be committed to GitHub?

GitHub stores the reproducible definition of the system:

```text
Python source
tests
Azure ML YAML
environment definitions
documentation
architecture decisions
```

The generated Azure job artifacts do **not** need to be committed to the repository. They remain attached to the Azure ML run / artifact storage.

The first successful run was documented separately in:

```text
docs/decisions/0003-first-azure-ml-job.md
```

---

## 11. Re-running after a repository change

For a disposable Cloud Shell session, the cleanest approach is simply to use the current repository state:

```bash
cd ~
rm -rf wkr-automotive-forecasting-lab
git clone https://github.com/sayac007/wkr-automotive-forecasting-lab.git
cd wkr-automotive-forecasting-lab
```

Then submit again:

```bash
az ml job create   --file azureml/calendar_job.yml   --resource-group rg-wkr-ml   --workspace-name mrw-wkr-forecasting
```

Azure generates a new job name for each run. Use that new name for subsequent `show`, `stream`, and `download` commands.

If the shell already contains the repository and the local copy has not been modified, a normal Git update is enough:

```bash
git pull
```

---

## 12. Debugging rule

When a job fails:

```text
Do not edit the production code interactively in Azure.
```

Use the failure to identify the broken layer:

```text
YAML validation
environment/dependency build
compute provisioning
input mounting
Python execution
output writing
business validation
```

Fix the relevant source file in the repository, commit the change, obtain that repository version in Cloud Shell, and submit a new run.

This preserves the relationship:

```text
Git commit → Azure ML run → logs → outputs
```

and prevents the cloud environment from becoming an undocumented second development machine.

---

## 13. Current WKR execution pattern

The working reference pattern is now:

```text
GitHub
  ↓
Azure Cloud Shell / Azure CLI
  ↓
azureml/calendar_job.yml
  ↓
Azure ML workspace
  ↓
cpu-cluster
  ↓
declared environment
  ↓
calendar_pipeline.py
  ↓
named Azure ML outputs
  ↓
business validation
```

This is the baseline for the next engineering step: decomposing the single command job into reusable Azure ML components and a pipeline while preserving the same repository-first execution model.
