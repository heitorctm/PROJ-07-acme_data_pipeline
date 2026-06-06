# acme_data_pipeline

**End-to-end ELT data pipeline for a SAP Business One → Power BI analytics stack** — ingestion,
dbt (Kimball) transformation, and Airflow orchestration. Four independent components that together
take raw operational data from SAP and SharePoint and turn it into a tested, documented data
warehouse ready for BI.

> **Portfolio note.** This is a **real production project**, anonymized and translated to English for
> publication. "Acme" is a fictitious stand-in for the real company; credentials, infrastructure
> identifiers, people's names and sample business data were removed or replaced. The engineering is
> the original. In production each component is its **own repository**; they are grouped here as one
> monorepo so the whole system can be read from a single place.

---

## Architecture

```
 SOURCES                 INGESTION  (Extract + Load)            TRANSFORM (dbt)               CONSUMPTION
┌──────────────┐        ┌────────────────────────────┐                                      
│ SAP Business │        │ acme-sap-ingestion         │                                      
│ One (HANA)   │──────► │ linked server + SQL Agent  │───► raw_sap ──────┐                   
└──────────────┘        │ OPENQUERY push-down, incr. │                   │                   
                        └────────────────────────────┘                   ▼                   
                                                                ┌────────────────────────────┐   ┌──────────┐
┌──────────────┐         ┌────────────────────────────┐         │ acme-dw-dbt                │   │          │
│ SharePoint   │ ──────► │ acme-sharepoint-connector  │ ─────►  │ staging → int → mart       │──►│ Power BI │
│ (Excel)      │ ◄────── │ Microsoft Graph (2-way)    │ raw_shp │ Kimball · ~450 tests ·     │   │          │
└──────────────┘ publish └────────────────────────────┘         │ Elementary observability   │   └──────────┘
                                                                └────────────────────────────┘   
                                                                                              
        ▲ schedules / data-aware (Assets) ───────  acme-airflow  ───────────────────────────►
```

- **Medallion layout** in one SQL Server (`SAP_MIRROR`): `raw_*` (mirror of sources) → `stg_*`
  (clean) → `int_*` (enriched) → `mart_*` (star schemas for BI), plus an `elementary` schema for
  observability and a shared `audit.ingestion_log` written by both ingestion paths.
- **ELT, not ETL**: data lands raw, then is transformed *inside* the warehouse with dbt.
- **Data-aware orchestration**: a "common" pacemaker DAG rebuilds shared dimensions hourly and emits
  Airflow **Assets** that trigger each fact build on its own cadence — no fixed cross-DAG timing.

---

## Components

| Component | Role | Stack |
|---|---|---|
| [`acme-sap-ingestion`](acme-sap-ingestion/) | SAP HANA → `raw_sap`, DB-to-DB via linked server + SQL Server Agent jobs; data-driven generator (Python) emits the seed/procs/jobs from a `tables.yaml` | T-SQL, Python (PyYAML) |
| [`acme-sharepoint-connector`](acme-sharepoint-connector/) | Two-way SharePoint integration over Microsoft Graph: ingests Excel spreadsheets → `raw_sharepoint`, and publishes reports back to SharePoint | Python (pandas, pyodbc, requests) |
| [`acme-dw-dbt`](acme-dw-dbt/) | The data warehouse: `staging → intermediate → mart` (Kimball), ~450 tests, reusable macros, Elementary observability | dbt-core, dbt-sqlserver, Elementary |
| [`acme-airflow`](acme-airflow/) | Orchestration: 6 domain/cadence DAGs that build dbt, the SharePoint extraction DAG, and report publishing; Dockerized, LocalExecutor | Apache Airflow 3, Docker |

Each component has its **own README** (a deep-dive on its design and how it runs in production).

---

## How the pieces connect

1. **Ingestion** keeps the `raw_*` layer fresh. SAP runs on SQL Server Agent jobs (outside Airflow);
   SharePoint runs as an Airflow DAG. Both follow the same principle: **a table's refresh cadence
   matches the cadence of the dbt model that consumes it**, so the source is fresh *before* each
   transformation.
2. **`acme-dw-dbt`** reads `raw_sap` / `raw_sharepoint` and builds the warehouse. Naming is consistent
   across the whole pipeline (e.g. `raw_sap.OINV` → `stg_sap.sales_invoice_oinv` → `fact_sales`).
3. **`acme-airflow`** ties it together: the `dbt_common` DAG is the hourly pacemaker; finishing it
   emits Assets (`common_ready`, `inventory_window`, `goals_window`) that trigger `dbt_sales`,
   `dbt_inventory`, `dbt_goals`, etc. A single-slot `dbt` pool serializes builds to protect a small
   (2 vCPU) server.
4. Both ingestion paths log to the **same `audit.ingestion_log`** table, so monitoring is unified.

---

## Tech stack

SQL Server · SAP Business One (HANA) · Microsoft Graph · dbt (Kimball / medallion) · Elementary ·
Apache Airflow 3 · Docker · Python · Power BI (consumer).

---

## Repository layout

```
acme_data_pipeline/
├── acme-sap-ingestion/         # SAP HANA → raw_sap  (T-SQL + Python generator)
├── acme-sharepoint-connector/  # SharePoint ⇄ raw_sharepoint  (Python / Graph)
├── acme-dw-dbt/                # raw → staging → int → mart  (dbt, Kimball)
├── acme-airflow/               # orchestration  (Airflow DAGs, Docker)
├── README.md                   # you are here
└── LICENSE
```

## License

[MIT](LICENSE) © 2026 Heitor Teixeira.
