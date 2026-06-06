# 05_monitoring — ingestion health

Replaces the old ad-hoc post-load queries with real monitoring: the log table
**self-heals** and there are **2 views** that tell you directly what is broken,
at both levels.

## How it works

**Self-healing (in the procs):** when a proc starts and grabs the `applock`, it closes any
previous `running` entry for the same table as **`interrupted`** (the `applock` is proof that
the previous run died). This way the table never accumulates orphans — a canceled/killed run stops
"running forever". It lives in `02_procs/01_usp_ingest_table.sql` and in the generated
dedicated procs (via `_log_abre` in the generator). Possible statuses in `audit.ingestion_log`:
`running` → `success` | `error` | `interrupted`.

## Files (apply in this sort_order)

1. **`01_cleanup_orphans.sql`** — marks current orphans (`running` > 60 min) as `interrupted`.
   Idempotent; run it once now to clear the backlog and, if you like, schedule it once a day as a safety net.
2. **`02_vw_issues.sql`** — creates `audit.vw_issues`.
3. **`03_vw_jobs.sql`** — creates `audit.vw_jobs`.

## Day-to-day usage

**What is broken right now (table-level):**
```sql
SELECT * FROM audit.vw_issues;
```
Shows, per table, only when the **latest** execution was `error`, `interrupted` or `stuck`
(`running` > 60 min). **Empty = everything OK.** When the table runs again successfully, it
disappears from here on its own.

**Are the jobs running (SQL Agent-level):**
```sql
SELECT * FROM audit.vw_jobs ORDER BY job;
```
Latest execution of each `ingestion_*`: `result` (success/failed/canceled/running),
`last_run`, `min_since` (how long ago). Here you see failures that never reach the
proc and jobs that **did not fire** (the `min_since` grows). Cadence reference:
`ingestion_hourly` ~60 min, `ingestion_inventory` ~180 min, the rest daily ~24 h (outside the
06:30–21:30 window the hourly/inventory ones sit idle — high `min_since` at night is normal).

## Pre-flight (setup) — meta tables with no object in raw_sap
This was "query 5" of the old checks; it only matters at setup / for a new table (today they all exist):
```sql
SELECT m.table_name, m.load_group
FROM meta.ingestion_table m
WHERE m.active = 1
  AND OBJECT_ID('raw_sap.' + QUOTENAME(m.table_name), 'U') IS NULL
ORDER BY m.table_name;
```

## Proactive alerting (optional, requires Database Mail)
The ideal is not to depend on watching a view: set up e-mail notification on job failure
(SQL Agent operator + `sp_update_job @notify_level_eml`). If Database Mail is available on the server,
you can wire it into all 5 jobs — ask for the script.
