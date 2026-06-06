# acme-sap-ingestion — SAP Business One (HANA) → SQL Server raw layer → `raw_sap`

Ingestion of the DW's **raw** layer (medallion): materializes SAP Business One tables
(SAP HANA) into `SAP_MIRROR.raw_sap` (SQL Server), where dbt (a dbt project) reads them as a *source*.

Ingestion is **DB-to-DB via linked server + SQL Server Agent** — there is no longer a Python pipeline.
Since SQL Server and SAP HANA live in the same data center, SQL Server pulls from HANA via
`OPENQUERY` (push-down, set-based), with an **incremental strategy** on the heavy tables.

> **Portfolio note.** This is a real production project, **anonymized** and translated to English for
> publication. "Acme" is a fictitious stand-in for the real company; branch/store/partner sample data,
> people's names, credentials and infrastructure identifiers (linked server, HANA schema, hosts) were
> replaced or removed. The engineering — the data-driven generator, the incremental strategies, the
> self-healing audit and SQL Agent orchestration — is that of the original project. The downstream dbt
> warehouse and Airflow orchestration are sibling folders in this monorepo.

```
SAP HANA (SAP_PROD)
      │  OPENQUERY(HANA_LINK)  — push-down, set-based
      ▼
SQL Server  →  raw_sap   (mirror of the SAP tables)
            →  audit     (execution log + self-healing)
            →  meta      (catalog of what/how/when to ingest)
            →  etl        (ingestion procedures)
      │  SQL Server Agent jobs by CADENCE (follow the dbt DAGs)
      ▼
dbt (the dbt project) reads raw_sap   ·   Airflow (an Airflow project) schedules dbt
```

## Principle

**Each table's ingestion cadence = the cadence of the dbt DAG that consumes it.** The source
is kept fresh *before* every transformation. Since an hourly `full_reload` would lock up the
production HANA, the heavy tables refreshed intraday use each one's **natural incremental
strategy** (a cheap delta), mirroring the previous Python pipeline.

## Load strategies (source strategy, in `tables.yaml`)

The column below is each table's **natural** strategy (`source_strategy` in `meta`). The
**executed** strategy may differ: only the **12 tables with a dedicated proc**
(`load_group = individual`) run incrementally; all the others execute `full_reload` in their
cadence group (`hourly`/`inventory`/`purchases`/`nightly`), via `usp_ingest_group` — regardless of
the source. (That's why "purchases" shows up as a group executed in full, even though its tables are
incremental at the source.)

| Source strategy | What it does | Tables (examples) |
|---|---|---|
| `incremental_upsert` | watermark (`UpdateDate`[+`UpdateTS`]) from raw itself → delete-by-PK + insert | OINV, OQUT, ORDR, OINM (dedicated); OPCH, OPOR, OPRQ, ORIN, ODLN (run full in the group) |
| `incremental_via_header` | rows without their own watermark: `DocEntry IN (header WHERE watermark)` | INV1/INV6/INV12, QUT1/QUT12, RDR1 (dedicated); PCH1, POR1, PRQ1, RIN1, DLN1 (run full in the group) |
| `incremental_append` | immutable ledger: watermark `RefDate`, idempotent on the cutoff day | JDT1, OJDT |
| `full_reload` | TRUNCATE + full INSERT | dims/master data, inventory (OITW/ITM1), PCH6/PCH12, orphans (OHEM/AHEM/@PROFIT_RANKING) |

The document families (`usp_ing_fam_*`) pre-capture the header watermark **before** reloading it
and use it in the header upsert and in the via_header of the rows.

## Job cadence (SQL Agent)

| Job | Time | Serves dbt DAG |
|---|---|---|
| `ingestion_nightly` | 03:00 | no scheduled consumer (ledger, payments, orphans) |
| `ingestion_daily_movement` | 04:00 | `mov_diaria` (05:00) |
| `ingestion_purchases` | 05:00 | `compras_fin` (06:00) |
| `ingestion_hourly` | 06:30→21:30 (hourly) | `comum` + `sales` (07:00–22:00) |
| `ingestion_inventory` | 06:30, 09:30, …, 21:30 (every 3h) | `estoque` (07,10,13,16,19,22) |

## Structure

```
tables.yaml                 # source of truth: tables, columns, strategy, watermark
linked_server/
├── _generator/generate_sql.py   # generates seed + procs + jobs from tables.yaml (build-time, does not touch the DB)
├── 00_infra/               # schemas, audit.ingestion_log, meta.ingestion_table, raw DDL
├── 01_seed/                # MERGE of meta.ingestion_table (generated)
├── 02_procs/               # usp_ingest_table (generic), usp_ingest_group, dedicated/ (generated)
├── 03_jobs/                # SQL Agent jobs by cadence (generated)
├── 04_validation/           # linked server smoke test + incremental test
├── 05_monitoring/       # self-healing + views audit.vw_issues / audit.vw_jobs
└── docs/                   # 01_config_sql_agent · 04_runbook_incremental_cadence
docs_sap/                   # reference: description of each source SAP table
```

## The generator

`tables.yaml` is the source of truth. When you change it, regenerate the SQL artifacts:

```bash
pip install -r requirements.txt        # pyyaml only
python linked_server/_generator/generate_sql.py
```

It rewrites `01_seed/`, `02_procs/dedicated/` and `03_jobs/`. **It does not touch the DB** — you apply the
`.sql` files on SQL Server (see runbook).

## Deploy and operation

Full step-by-step (constraint → seed → procs → validation → scheduling):
**`linked_server/docs/04_runbook_incremental_cadence.md`**.
SQL Agent configuration: `linked_server/docs/01_config_sql_agent.md`.

## Monitoring

`audit.ingestion_log` is **self-healing** (a stuck run becomes `interrupted` on the next load).
Check two views:

```sql
SELECT * FROM audit.vw_issues;        -- tables with error/interrupted/stuck (empty = ok)
SELECT * FROM audit.vw_jobs ORDER BY job; -- last run of each job (success/failure/when)
```
Details in `linked_server/05_monitoring/README.md`.

## Notes

- Linked server `HANA_LINK` (provider MSDASQL + HDBODBC) configured on SQL Server; the **`raw_sap`
  contract** (names/columns/types) is kept for dbt.
- The **SQL Server Agent** service account needs access to the linked server.
- No credentials in the repository — the HANA connection lives in the linked server (SQL Server), not in a file.
