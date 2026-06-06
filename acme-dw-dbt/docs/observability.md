# Observability — Elementary

dbt-native monitoring via [Elementary](https://docs.elementary-data.com): captures
project runs, tests, and anomalies and generates a local HTML report. Runs 100%
on top of SQL Server, with no external service.

---

## Stack

| Component | Version | Function |
|---|---|---|
| `elementary-data` (CLI `edr`) | 0.23.4 | generates the HTML report from the tables in the DW |
| dbt package `elementary-data/elementary` | 0.23.1 | materializes the observability tables in the `elementary` schema |

Versions pinned in `pyproject.toml` (CLI) and `packages.yml` (dbt package). Keep
major.minor aligned between the two.

---

## How it works

1. **Automatic collection** — the elementary dbt package injects an `on-run-end` hook that,
   on every `dbt run`/`dbt test`, writes metadata into tables in the `elementary` schema
   (models executed, duration, status, test results, schema changes).
2. **HTML report** — the `edr` CLI reads those tables and generates a static
   `edr_target/elementary_report.html` with Tests, Models, Runs, and Anomalies tabs.
3. **Anomaly detection** — after ~7 days of history (`min_training_set_size`),
   elementary starts flagging statistical deviations in model metrics.

It doesn't change the developer workflow: any normal `.\dbt.ps1 run`
or `.\dbt.ps1 test` execution already feeds the history.

---

## Commands

Use the `edr.ps1` wrapper (it loads `.env` and points `--profiles-dir .`). **Always** pass
`--profile-target prod` — the `dev` target is disabled on purpose and the command fails without it.

```powershell
.\edr.ps1 report --profile-target prod     # generates edr_target/elementary_report.html
.\edr.ps1 monitor --profile-target prod    # fires alerts (requires Slack/Teams config — see "Roadmap")
```

---

## Setup (reference — already applied)

In case you need to reapply from scratch (new environment, fresh repo):

1. **Python dependency** in `pyproject.toml`:
   ```toml
   "elementary-data[sqlserver]==0.23.4",
   ```
   Run `uv sync`.

2. **dbt package** in `packages.yml`:
   ```yaml
   - package: elementary-data/elementary
     version: 0.23.1
   ```
   Run `.\dbt.ps1 deps`.

3. **Dedicated schema** in `dbt_project.yml` (`models:` block):
   ```yaml
   elementary:
     +schema: elementary
     +tags: ['elementary', 'observability']
   ```

4. **`elementary` profile** in `profiles.yml` pointing to the same database with `schema: elementary`.

5. **Materialize the tables**:
   ```powershell
   .\dbt.ps1 run --select elementary --target prod
   ```

---

## SQL Server 2019 quirks

elementary's SQL Server support dates from v0.23.x (recent) and has two mandatory
adjustments to run on SQL Server 2019.

### 1. `DATETRUNC()` does not exist

The `DATETRUNC()` function only exists from SQL Server 2022 onward. The package calls it via
`fabric__edr_date_trunc` / `fabric__edr_time_trunc`. Without an override, three elementary
models break (`metrics_anomaly_score`, `model_run_results`,
`dbt_columns`).

**Solution** — `macros/sqlserver__edr_date_trunc.sql` defines overrides using the
`DATEADD(unit, DATEDIFF(unit, 0, expr), 0)` pattern, compatible with any
SQL Server version. So that dispatch can find them, `dbt_project.yml` has:

```yaml
dispatch:
  - macro_namespace: elementary
    search_order: ['acme_dw', 'elementary']
```

### 2. Limit of 1000 row values per INSERT

elementary inserts dbt artifacts in chunks of 5000 by default. SQL Server
has a hard limit of 1000 row values per INSERT statement — when the project's
catalog exceeds that (in Acme's case, ~3000 columns), `dbt_columns` breaks
with error `10738`.

**Solution** — `vars:` in `dbt_project.yml`:

```yaml
vars:
  dbt_artifacts_chunk_size: 500
```

---

## Database structure

Schema `elementary` (~30 tables). The most queried:

| Table | What it holds |
|---|---|
| `dbt_invocations` | one row per `dbt run`/`dbt test` executed |
| `dbt_run_results` | result of each model in each invocation |
| `dbt_models`, `dbt_tests`, `dbt_sources` | catalog (fed on every run) |
| `dbt_columns` | column metadata (~3000 rows in the project) |
| `elementary_test_results` | test results with a sample of failing rows |
| `data_monitoring_metrics` | historical metrics for anomaly detection |
| `metrics_anomaly_score` | statistical score of each metric vs the training window |

---

## Roadmap

Steps to evolve the project's observability:

- **Accumulate history** — run dbt regularly. After 7+ days with runs/tests, the report's
  Anomalies tab starts showing data.
- **Slack/Teams alerts** — configure a webhook in `~/.edr/config.yml` and schedule
  `.\edr.ps1 monitor --profile-target prod` in Airflow or Task Scheduler. Docs:
  [docs.elementary-data.com/oss/integrations](https://docs.elementary-data.com/oss/integrations/slack).
- **Anomaly tests in dbt** — add elementary tests to critical models:
  ```yaml
  models:
    - name: fact_sales
      tests:
        - elementary.volume_anomalies
        - elementary.freshness_anomalies
  ```
- **Publish the HTML** — upload `edr_target/elementary_report.html` to a bucket
  or shared folder after each build, so the whole team can access it without running `edr` locally.
