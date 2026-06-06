# linked_server — SAP HANA → `raw_sap` ingestion without Python

The **raw** layer ingestion done entirely in SQL Server, via the `HANA_LINK` linked server
(OPENQUERY) + SQL Server Agent. It replaces the Python pipeline as the
insertion source. It keeps the `raw_sap` contract that the **dbt project** consumes.

```
SAP HANA (SAP_PROD)  --OPENQUERY(HANA_LINK)-->  SQL Server SAP_MIRROR.raw_sap
                                                        control:   meta.ingestion_table
                                                        log:       audit.ingestion_log
                                                        engine:    etl.usp_*
                                                        scheduler: SQL Agent (jobs)
```

## How it works

- **Cadence derived from the dbt DAGs:** each table is ingested at the cadence of the DAG
  that consumes it (the source is fresh *before* each transformation). There are **5 SQL Agent
  jobs by cadence** — `ingestion_hourly`, `ingestion_inventory`, `ingestion_daily_movement`,
  `ingestion_purchases`, `ingestion_nightly` (details in `docs/04_runbook_incremental_cadence.md`).
- **Mixed strategy** (defined per table_name in `tables.yaml`):
  - **Incremental, via dedicated proc** (12 tables, `load_group = individual`): the 3
    document families — `usp_ing_fam_sales_invoice` (OINV+INV1+INV6+INV12),
    `usp_ing_fam_quote` (OQUT+QUT1+QUT12), `usp_ing_fam_sales_order` (ORDR+RDR1),
    with `incremental_upsert` header and `incremental_via_header` rows — plus
    `usp_ing_OINM` (upsert) and `usp_ing_JDT1`/`usp_ing_OJDT` (idempotent append).
  - **`full_reload` via generic proc** (`etl.usp_ingest_group @group = '<cadence>'`):
    all the rest, in the `hourly` (20 light dims/sales), `inventory` (OITW, ITM1),
    `purchases` (7), and `nightly` (10, no scheduled consumer) groups.
- **Metadata-driven:** `meta.ingestion_table` says what/from where/how/when to ingest
  (stores the executed `strategy`, the yaml's `source_strategy`, and the `load_group`).
  `etl.usp_ingest_table` is the generic proc for **one** table_name; `etl.usp_ingest_group`
  runs an entire group in `full_reload`.
- **Date slice:** the incrementals use the table's natural watermark (read from `raw_sap`
  itself); the only one with a fixed slice by volume is **OINM** (`DocDate >= '2025-07-01'`).

## Structure

| Folder | Contents |
|-------|----------|
| `00_infra/` | schemas, `audit.ingestion_log`, `meta.ingestion_table` |
| `01_seed/` | seed for `meta.ingestion_table` *(generated)* |
| `02_procs/` | `usp_ingest_table`, `usp_ingest_group` (generic, hand-maintained) + `dedicated/` — 6 incremental procs *(generated)* |
| `03_jobs/` | `10_jobs_cadence.sql` — the 5 jobs by cadence *(generated)* |
| `04_validation/` | linked server smoke test + post-load checks |
| `05_monitoring/` | orphan self-healing + `audit.vw_issues` / `audit.vw_jobs` views |
| `docs/` | Agent config · incremental cadence runbook |
| `_generator/` | `generate_sql.py` — regenerates seed/dedicated-procs/jobs from `tables.yaml` |

## Order of use (summary)

1. **Deploy** (does not touch HANA): `00_infra/*` → `01_seed/*` → `02_procs/*` (generic + `dedicated/`).
2. **Pre-flight:** "meta without raw_sap" query in `05_monitoring/README.md` — make sure
   the `raw_sap` tables exist.
3. **Linked server smoke** (touches HANA, authorize): `04_validation/00_smoke_linked_server.sql`.
4. **Validate loads** (touches HANA): run the dedicated procs (`usp_ing_fam_*`,
   `usp_ing_OINM`/`usp_ing_JDT1`/`usp_ing_OJDT`) and the groups
   (`usp_ingest_group @group='hourly'|'inventory'|'purchases'|'nightly'`) — see PHASE 5 of the runbook.
5. **Jobs and scheduling:** `03_jobs/10_jobs_cadence.sql` (creates the 5 jobs; schedules are born
   `@enabled=0`) and enable the schedules.

Full step by step in **`docs/04_runbook_incremental_cadence.md`**.

## Regenerate (when `tables.yaml` changes)

```bash
python linked_server/_generator/generate_sql.py
```
Build-time only; **does not access any database** (only reads the yaml and writes `.sql`).

## Warnings

- `HANA_LINK` points to **production**. Nothing that crosses the linked server runs
  without authorization and outside off-peak hours.
- The job schedules come **disabled** — enable only after validating.
- The test → `SAP_PROD` cutover changes the numbers in the marts; validate with the
  business before turning scheduling on.
```
