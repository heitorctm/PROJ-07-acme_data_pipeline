# SQL Server Agent configuration

How to keep the ingestion running on its own via the Agent. The jobs already come ready in
the `03_jobs/` scripts; here is what needs to be in place and how to turn it on.

> Assumption: the linked server `HANA_LINK` already exists and responds (`SELECT 1 FROM DUMMY`
> passes), and the SQL Server Agent is running on `SAP_MIRROR`.

---

## 1. Prerequisites (one time)

| Item | How to check |
|------|---------------|
| Agent running | SSMS → SQL Server Agent with a green arrow, or `SELECT 1 FROM sys.dm_server_services WHERE servicename LIKE 'SQL Server Agent%' AND status = 4` |
| Linked server OK | run `04_validation/00_smoke_linked_server.sql` (test 0) **with authorization** |
| `rpc out` enabled on HANA_LINK | already is (confirmed) |
| Objects created | run the deploy sort_order from `docs/04_runbook_incremental_cadence.md` |
| `raw_sap` tables exist | "meta without raw_sap" query in `05_monitoring/README.md` |

---

## 2. Permissions for the Agent service account

The job runs under the **SQL Server Agent service account** (or a proxy). That account
needs:

- In the `SAP_MIRROR` database: execute the `etl.*` procs, `TRUNCATE`/`INSERT` on
  `raw_sap.*`, `INSERT`/`UPDATE` on `audit.ingestion_log`, `SELECT` on
  `meta.ingestion_table`. The simplest option is `db_owner` on `SAP_MIRROR` (a dedicated
  DW environment) or a role with those permissions.
- The right to use the `HANA_LINK` linked server. The linked server login mapping
  (already configured) defines which HANA user the query runs as — confirm it
  applies to the Agent account, not just to your own login.

> If the job fails when scheduled with "EXECUTE permission denied" or a linked server
> error, it is a service-account permission issue — not a script issue.

---

## 3. What the scripts create

A single script — `03_jobs/10_jobs_cadence.sql` — creates **5 jobs by cadence** (the cadence
follows the dbt DAGs). Each job calls the dedicated procs and/or `etl.usp_ingest_group`:

| Job | Cadence | Steps (in sort_order) |
|-----|----------|-------------------|
| `ingestion_hourly` | 06:30→21:30, hourly | group `hourly` → family `sales_invoice` → family `quote` → family `sales_order` |
| `ingestion_inventory` | 06:30→21:30, every 3h | `usp_ing_OINM` → group `inventory` (OITW+ITM1) |
| `ingestion_daily_movement` | 04:00 | `usp_ing_OINM` |
| `ingestion_purchases` | 05:00 | group `purchases` |
| `ingestion_nightly` | 03:00 | `usp_ing_JDT1` → `usp_ing_OJDT` → group `nightly` |

All jobs:
- are created with `@enabled = 1` (the **job** can run), but the **schedule** comes
  with `@enabled = 0` — i.e., it **does not fire on its own** until you enable it;
- run on the `SAP_MIRROR` database, T-SQL subsystem;
- are idempotent on deploy (they drop and recreate if they already exist);
- in the multi-step jobs, each step uses `@on_fail_action = 2` (quit failure): if a step
  fails, the cycle stops and alerts; the next cycle resumes.

---

## 4. Enable and schedule

The schedules already come with the right times, just **disabled** (`@enabled = 0`).
After validating (see PHASE 5 of the runbook), turn each one on:

```sql
USE msdb;
EXEC sp_update_schedule @name = N'sched_ingestion_hourly',       @enabled = 1;
EXEC sp_update_schedule @name = N'sched_ingestion_inventory',    @enabled = 1;
EXEC sp_update_schedule @name = N'sched_ingestion_daily_movement', @enabled = 1;
EXEC sp_update_schedule @name = N'sched_ingestion_purchases',    @enabled = 1;
EXEC sp_update_schedule @name = N'sched_ingestion_nightly',    @enabled = 1;
```

The times are **already in the schedule** (they end with margin *before* the DAG they serve) — there is no
need to reset `@active_start_time`. For reference:

| Schedule | Time | DAG it serves |
|----------|---------|-----------------|
| `sched_ingestion_nightly` | 03:00 | no scheduled consumer (ledger, payments, orphans) |
| `sched_ingestion_daily_movement` | 04:00 | `mov_diaria` (05:00) |
| `sched_ingestion_purchases` | 05:00 | `compras_fin` (06:00) |
| `sched_ingestion_hourly` | 06:30→21:30 (hourly) | `comum` + `sales` (07:00–22:00) |
| `sched_ingestion_inventory` | 06:30→21:30 (every 3h) | `estoque` (07,10,13,16,19,22) |

Each ingestion window ends **before** the corresponding dbt DAG, which reads the already-fresh `raw_sap`.

---

## 5. Manual trigger (test/reprocess)

```sql
USE msdb;
EXEC dbo.sp_start_job @job_name = N'ingestion_hourly';        -- asynchronous
-- track:
EXEC dbo.sp_help_jobactivity @job_name = N'ingestion_hourly';
```

Or directly, without a job:

```sql
USE SAP_MIRROR;
EXEC etl.usp_ingest_group @group = 'purchases';   -- an entire full group
EXEC etl.usp_ing_fam_sales_invoice;                    -- one document family (header + rows)
EXEC etl.usp_ing_OINM;                            -- a standalone dedicated proc
EXEC etl.usp_ingest_table @table_name = 'OCRD';     -- a one-off table_name (generic full_reload)
```

---

## 6. Failure notification (optional, recommended)

```sql
USE msdb;
-- 1) create an operator with your email (one time), Database Mail configured:
-- EXEC sp_add_operator @name=N'data_alerts', @email_address=N'data-team@example.com';
-- 2) notify on failure (repeat for each job, or at least the production ones):
EXEC sp_update_job @job_name = N'ingestion_hourly',
     @notify_level_eventlog = 2,           -- Windows log on failure
     @notify_level_email = 2, @notify_email_operator_name = N'data_alerts';
```

---

## 7. Monitoring

The source of truth for execution is `audit.ingestion_log`, with the table_name self-healing
(orphans become `interrupted`). Monitor through the views in `05_monitoring/`:
`audit.vw_issues` (tables with error/interrupted/stuck) and `audit.vw_jobs`
(result of the last run of each Agent job). See `05_monitoring/README.md`.
