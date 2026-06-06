# acme_dw — Data Warehouse dbt (SAP Business One → Kimball)

dbt project that transforms raw SAP Business One data (ingested into the `raw_sap` schema)
into analytical layers following the Kimball pattern, ready for consumption in Power BI, AI agents and
ad-hoc analysis.

> **Portfolio note.** This is a real production project, **anonymized** for publication.
> "Acme Building Materials" is a fictitious name standing in for the real company; people's names,
> credentials and infrastructure identifiers were removed or replaced. The engineering
> (modeling, tests, macros, conventions) is that of the original project. Orchestration (Airflow) and
> ingestion (SAP via linked server, SharePoint via Microsoft Graph) are sibling folders in this
> monorepo (`acme-airflow`, `acme-sap-ingestion`, `acme-sharepoint-connector`).

---

## Overall architecture

```
Ingestion (outside dbt):
  SAP B1 (HANA) ── SQL Server Agent jobs (linked server HANA→SQL Server) ─► raw_sap
  SharePoint    ── ingestion pipeline (Microsoft Graph) ──────────────────►  raw_sharepoint
                                     │
                                     ▼
  stg_sap / stg_sharepoint   views: rename, cast, translate enums          (dbt)
        ↓
  int_<domain>               enriched bricks + consolidated facts           (dbt)
        ↓
  mart_<domain>              dimensions and facts (Kimball modeling) for BI  (dbt)
```

Target database: `SAP_MIRROR` (SQL Server).

> **Orchestration in production:** dbt runs in **6 DAGs by domain/cadence** in Airflow (in a
> separate orchestration repository) — there is no longer a monolithic build. **SAP ingestion** runs
> outside Airflow, in SQL Server Agent jobs (linked server). Locally, use `dbt.ps1`
> (see "Common commands").

---

## Database schema structure

Each layer has dedicated schemas. Layers that would mix data from different
domains use a source prefix; layers that unify by area use a domain prefix.

| Layer | Schema(s) | Owned by | Materialization |
|---|---|---|---|
| raw | `raw_sap`, `raw_sharepoint` (future: `raw_crm`) | ingestion outside dbt — SAP via **SQL Server Agent jobs**; SharePoint via ingestion pipeline | — |
| staging | `stg_sap`, `stg_sharepoint` (future: `stg_crm`) | dbt | view |
| intermediate | `int_common`, `int_sales`, `int_purchases`, `int_finance`, `int_inventory` | dbt | table |
| mart | `mart_common`, `mart_sales`, `mart_purchases`, `mart_finance`, `mart_inventory` | dbt | table |

**Why does `stg_sap` have no domain but `int_*` does?** A staging table can be
cross-domain (e.g., `business_partner_ocrd` is used by sales, purchases AND finance).
Forcing a domain into the staging schema would be artificial. Domain only appears starting at `int`.

---

## Stack

| Component | Version |
|---|---|
| dbt-core | 1.11.9 |
| dbt-sqlserver | 1.9.0 |
| dbt-utils | 1.3.3 |
| elementary-data | 0.23.4 (CLI) + 0.23.1 (dbt package) — see [docs/observability.md](docs/observability.md) |
| Python | managed by [uv](https://docs.astral.sh/uv/) |
| SQL Driver | ODBC Driver 18 for SQL Server |

---

## Setup

### Prerequisites

- [uv](https://docs.astral.sh/uv/) installed
- ODBC Driver 18 for SQL Server installed
- `.env` file created from `.env.example` (fill in the `DBT_PROD_*` variables)

### Installation

```powershell
uv sync                                # install Python dependencies
.\dbt.ps1 deps                         # install dbt packages (dbt_utils, elementary)
.\dbt.ps1 debug --target prod          # test the database connection
```

> **About `dbt deps` and `dbt_packages/`.** dbt packages (`dbt_utils`, `elementary`) are installed
> with `.\dbt.ps1 deps` and live in `dbt_packages/` (in `.gitignore`). Versions are pinned in
> `packages.yml`/`package-lock.yml`.
>
> Production note: in the original environment the server is private and **does not download from the internet**, so there
> the `dbt_packages/` folder was **version-controlled** (vendoring) so it would come along on `git pull`. Here, in the
> portfolio version, it was removed from version control — just run `dbt deps`.

---

## Common commands

Use the `dbt.ps1` script (it loads `.env` automatically before calling dbt).

> **Always use `--target prod` in local commands.** Today there is only one database instance (PROD);
> the `dev` target is disabled on purpose (safety net). Any command that connects
> without `--target prod` fails with a clear message, instead of accidentally writing to production.

```powershell
# full build (run + test)
.\dbt.ps1 build --target prod

# run an entire layer
.\dbt.ps1 run --select tag:staging --target prod
.\dbt.ps1 run --select tag:int --target prod

# run a model + everything that depends on it
.\dbt.ps1 run --select item+ --target prod              # item + 16 models that join with item
.\dbt.ps1 run --select +sales_fiscal_lines --target prod   # everything that feeds sales_fiscal_lines

# resume after a failure
.\dbt.ps1 retry --target prod

# tests
.\dbt.ps1 test --target prod
.\dbt.ps1 test --select finance_journal_entries --target prod

# docs
.\dbt.ps1 docs generate --target prod
.\dbt.ps1 docs serve

# observability (Elementary) — generates edr_target/elementary_report.html
.\edr.ps1 report --profile-target prod
```

**Useful selection operators:**
- `+model` — model + all ancestors
- `model+` — model + all descendants
- `+model+` — ancestors + model + descendants
- `tag:X` — all models with the tag X
- `path:models/intermediate/sales/` — everything in a folder

---

## File structure

```
acme_dw/
├── dbt_project.yml              # config for schemas, tags and materialization by folder
├── packages.yml                 # dbt dependencies (dbt_utils)
├── profiles.yml                 # SQL Server connection via env vars
├── pyproject.toml + uv.lock     # Python dependencies via uv
├── dbt.ps1                      # PowerShell wrapper that loads .env
├── edr.ps1                      # wrapper for the `edr` CLI (Elementary observability)
├── .env.example                 # environment variables template
│
├── docs/                        # documentation by topic (the overview lives in this README)
│   └── observability.md       # Elementary setup and operation
│
├── macros/
│   ├── digits_only.sql             # extracts digits only (cleaning of CPF/CNPJ etc.)
│   ├── filtros_bi.sql                 # macros for the canonical BI filters (sales/purchases)
│   ├── generate_schema_name.sql       # does not prefix schema with target
│   ├── indices.sql                    # DRY macro for indexing post-hooks
│   ├── normalize_brazilian_decimal.sql     # converts pt-BR "1.058,50" to decimal
│   ├── sqlserver__edr_date_trunc.sql  # DATETRUNC patch for Elementary on SQL Server 2019
│   └── sqlserver__last_day.sql        # patch for a sqlserver adapter bug
│
├── models/
│   ├── staging/
│   │   ├── sap/                       # 48 views — source prefix (sap)
│   │   │   ├── _sources.yml
│   │   │   ├── sales/        ← 17 models
│   │   │   ├── purchases/       ←  8 models
│   │   │   ├── master_data/     ← 12 models
│   │   │   ├── items/         ←  7 models
│   │   │   └── finance/    ←  4 models
│   │   └── sharepoint/                # 3 views — spreadsheets from the business areas
│   │       ├── master_data/     ←  1 model (store_mapping)
│   │       └── sales/        ←  2 models (wholesale_goals, retail_goals)
│   │
│   ├── intermediate/                  # 45 tables
│   │   ├── partner.sql, item.sql, item_price_list.sql, warehouse.sql, user.sql,
│   │   │  employee.sql, standardized_store.sql, salesperson_bridge.sql  # cross-domain (8)
│   │   ├── sales/        ← 24 models (bricks by type + consolidated facts)
│   │   │   ├── _vendas__docs.md       # reusable docs blocks
│   │   │   └── ...
│   │   ├── purchases/       ←  9 models
│   │   │   ├── _compras__docs.md
│   │   │   └── ...
│   │   ├── finance/    ←  2 models
│   │   └── inventory/       ←  2 models (current_inventory, inventory_movements)
│   │
│   └── marts/                         # 12 tables
│       ├── dim_date.sql, dim_item.sql, dim_partner.sql, dim_store.sql,
│       │  dim_warehouse.sql, dim_employees.sql                 # cross-domain dimensions (6)
│       ├── sales/        ←  2 models (fact_sales, fact_goals)
│       ├── purchases/       ←  1 model  (fact_purchases)
│       ├── finance/    ←  1 model  (fact_accounts_receivable)
│       └── inventory/       ←  2 models (fact_inventory + fact_daily_inventory_movement)
│
├── tests/                             # singular tests (non-generic)
│   ├── financeiro_lancamentos_debito_xor_credito.sql
│   ├── financeiro_lancamentos_partida_dobrada.sql
│   ├── bridge_vendedor_sem_sobreposicao_de_periodos.sql
│   └── bridge_vendedor_uma_versao_vigente_por_vendedor.sql
│
└── analyses/                          # ad-hoc scripts / validation queries (empty today)
```

---

## Conventions

### Naming

| Layer | Folder | Name pattern | Example |
|---|---|---|---|
| stg | `models/staging/<source>/<domain>/` | `<context>_<sapcode>.sql` | `sales_invoice_oinv.sql` |
| int (cross-domain) | `models/intermediate/` | `<entity>.sql` | `partner.sql` |
| int (domain) | `models/intermediate/<domain>/` | `<domain>_<scope>_<grain>.sql` | `sales_fiscal_documents.sql` |
| mart (cross-domain) | `models/marts/` | `dim_<entity>` or `fato_<subject>` | `dim_date.sql` |
| mart (domain) | `models/marts/<domain>/` | same | (future) |

### "1 brick per type, fact is just a UNION" pattern

In sales and purchases, each document type (nf, orc, dev, ped, req) has **its own
enriched brick** (`sales_invoice_documents`, `sales_quote_documents`...) with all the
type-specific logic (dedup, translation CASEs, joins). The **consolidated facts** (`sales_fiscal_documents`,
`sales_fiscal_lines`, `purchases_fiscal_documents`, `purchases_fiscal_lines`) are **pure UNION ALL**
of those bricks — with no additional logic. The `document_type` discriminator allows filtering/grouping.

### Filter policy

**Facts do not filter.** Cancelled, intercompany, hidden from BI — everything is preserved in the
`int` layer. Each consuming mart is the one that decides the whitelist appropriate for its use case.
Details in each domain's docs blocks (`models/intermediate/<dom>/_<dom>__docs.md`).

### Indexing

All `int` and `mart` (table) models get a **clustered unique index** on the grain
key via the `clustered_unique_index(['col1', 'col2', ...])` macro in `macros/indices.sql`.
No preemptive nonclustered indexes — add them only when a real query proves the need.

### Tags

Models carry tags for selection (`--select tag:X`) and for **domain-based orchestration** in
Airflow (6 DAGs per group, in the `acme-airflow` folder):

- **By layer** (via `dbt_project.yml`): `staging`, `int`, `mart`.
- **By domain** (via `dbt_project.yml`): `sales`, `purchases`, `finance`, `inventory`,
  `master_data`, `items`, `sap`, `sharepoint`.
- **`dimension`** (inline, on the 6 `dim_*`) — what the `dbt_comum` DAG builds together with the base.
- **`fact`** (inline, on the 6 facts: `fact_sales`, `fact_goals`, `fact_purchases`, `fact_accounts_receivable`,
  `fact_inventory`, `fact_daily_inventory_movement`) — symmetric counterpart of `dimension`, allows operating
  on the set of facts at once (e.g., `dbt test --select tag:fact`). Not used by
  orchestration (each fact enters its DAG through the `+fato_*` lineage).
- **`common`** (inline, on the 6 base `int_common` bricks: `item`, `partner`, `warehouse`,
  `standardized_store`, `employee`, `salesperson_bridge`) — shared base for dims and facts.
  > `user` and `item_price_list` (also `int_common`) do **not** carry `common` on purpose: they have a
  > single consumer (purchases / inventory) and enter through the fact's lineage, not through the base.

### Materialization

- **staging:** `view` — no latency, always fresh with the raw.
- **intermediate:** `table` — joins, dedup and enrichments materialized.
- **mart:** `table` by default. Exception: `fact_daily_inventory_movement` is `incremental` with `incremental_strategy='append'` (the OINM audit trail is immutable; each run appends newly closed days).

---

## Tests

**~450 active tests** (444 generic + 4 singular) covering:

- `unique_combination_of_columns` (dbt_utils) on facts with a composite key
- `relationships` (severity error) between facts↔dimensions in cases where 100% of the data matches
- `not_null` / `unique` on the keys
- `accepted_values` on discriminators and translated flags
- **Singular tests** (`tests/*.sql`) for specific invariants:
  - `financeiro_lancamentos_debito_xor_credito.sql` — each line is a debit OR a credit
  - `financeiro_lancamentos_partida_dobrada.sql` — `SUM(debit) = SUM(credit)` per transaction
  - `bridge_vendedor_sem_sobreposicao_de_periodos.sql` — periods of the same store do not overlap
  - `bridge_vendedor_uma_versao_vigente_por_vendedor.sql` — only 1 open period per (code, store)

```powershell
.\dbt.ps1 test                                    # all tests
.\dbt.ps1 test --select finance_journal_entries    # only for one model
```

---

## Additional documentation

| File | Content |
|---|---|
| [docs/observability.md](docs/observability.md) | Elementary: setup, `edr.ps1` commands, SQL Server 2019 quirks, roadmap for alerts |
| `models/intermediate/sales/_vendas__docs.md` | Reusable `{% docs %}` blocks for sales (fiscal usage, filter policy, etc.) |
| `models/intermediate/purchases/_compras__docs.md` | Same for purchases |

---

## Recent history

Relevant changes to the architecture:

- **SAP ingestion migrated to SQL Server Agent jobs** (linked server HANA→SQL Server, same data
  center) — it left the Python/Airflow extractor. `raw_sap` is still the staging source; only the
  party that populates it changes.
- **dbt orchestration by 6 DAGs per domain/cadence** (Airflow, in the `acme-airflow` folder), replacing the
  monolithic build: `dbt_comum` (base + dims, pacemaker) triggers sales/inventory/goals via
  Airflow Assets; `mov_diaria` and `compras_fin` via cron. Inline tags **`dimension`** (6 dims) and
  **`common`** (6 base `int_common` bricks) enable "one model = one owner", without duplicate rebuilds.
- **Multi-schema by layer + domain** — `stg_sap`, `int_sales/purchases/finance/common`, `mart_common`.
- **"1 brick per type, fact is just a UNION" refactor** — sales (4 types) and purchases (3 types)
  each have their own `_documentos`/`_linhas` pair; the consolidated facts are pure UNION ALL.
- **Order integration into the consolidated sales fact** — `document_type` is now ∈ {nf, orc, dev, ped}.
- **`dim_date`** via a native SQL Server tally table (2023-01-01 to 2035-12-31, attributes in pt-BR).
- **`packages.yml` with `dbt_utils 1.3.3`** — `dbt_date` was evaluated and discarded (it has no
  `sqlserver__` implementation).
- **Tests**: `unique_combination_of_columns` on all composite facts + `relationships`
  on the main fact–dimension crossings (~41 tests today) + accounting invariants via singular tests.
- **DRY indexing** — the `clustered_unique_index` macro replaced inline post_hooks on practically every model materialized as a table (56 today: 44 of 45 int — except `goal_name_entry` — + 12 marts).
- **inventory domain** — completed with `int_inventory.current_inventory` (OITW snapshot), `int_inventory.inventory_movements` (enriched OINM), `int_common.item_price_list` (prices per list, cross-domain), `mart_inventory.fact_inventory` (snapshot with turnover/coverage) and `mart_inventory.fact_daily_inventory_movement` (append-only history).
- **Layering rule** — a mart NEVER consumes staging directly. Every fact/dim consumes int. When an aggregating int does not exist, create it first with a grain compatible with the fact's consumption (without aggregating prematurely).
- **`current_price_list` var** in `dbt_project.yml` — controls which price list is the active one for valuing inventory at sale price (today = 100). Change it when Acme adopts a new list.
- **Observability via Elementary** — the `elementary` schema materializes metadata for each `dbt run`/`dbt test`. Local HTML report via `.\edr.ps1 report`. Details in [docs/observability.md](docs/observability.md).
- **100% SAP salesperson bridge** — `salesperson_bridge` (SCD2 incremental by SlpCode) derives the store from the **master record** (`OSLP.U_STORE`), no longer from the goal spreadsheets nor from the invoice. Baseline with `valid_from` dated by the salesperson's **1st goal** (via `goal_name_entry`, floor 2025-01-01; fallback 2025-10-01 for those with no goal) + forward-tracking via `pre_hook` (closes the period when `U_STORE` changes). The one-shot backfill and the `bridge_vendedor_historico` source were retired. `sales_goals` breaks namesake ties by `store_code` and now resolves codes from 2025 on (previously only Oct/2025+); `fact_goals` covers 2025+ (previously 2026+). `dim_employees.hire_date` = month of the 1st goal (floor 2025-01-01) — an onboarding proxy to flag a recent / "breakout" salesperson, not an HR hire date.
