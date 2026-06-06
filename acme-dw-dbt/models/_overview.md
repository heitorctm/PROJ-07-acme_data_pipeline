{% docs __overview__ %}

# Data Warehouse — Acme Building Materials

This is Acme's central analytics data repository. Here live the `dbt` models that transform raw data into **facts and dimensions** ready for consumption.

- **Where the data comes from:** SAP Business One (`raw_sap`, a mirror of SAP HANA ingested by a dedicated pipeline via linked server + SQL Agent) and spreadsheets from the commercial and administrative areas on SharePoint (`raw_sharepoint`: sales goals and the store mapping).
- **Who consumes it:** Power BI connects directly to the marts (`mart_*`); ad-hoc analyses also start from the marts. The earlier layers (`raw`/`stg`/`int`) are internal to the pipeline.
- **Database:** `SAP_MIRROR` (SQL Server), read-only for consumers.

## How to navigate

- **Project** — the dbt folder structure (same as the repository). Use it when you know which model you want to work on.
- **Database** — a view by database schema. Use it when you know the table but not where it lives in the code.
- **Search** — search by model or column name at the top of the page.

To open a fact or dimension, use the search or navigate the sidebar at **Project → acme_dw → models → marts → \<domain\>**.

## The 4 layers (Medallion)

The models follow the classic dbt convention of 4 layers (bronze → silver → gold), each with **one clear responsibility** and consuming only the layer immediately before it:

| | Layer | Schemas | Who consumes | Responsibility |
|:---:|---|---|---|---|
| | `raw_*` | `raw_sap`, `raw_sharepoint` | only `stg_*` | Faithful mirror of the source, no transformation. **Never consume it directly.** |
| 🥉 | `stg_*` | `stg_sap`, `stg_sharepoint` | only `int_*` | Standardizes names (snake_case) and types, **1:1 in grain** (1 row per raw row), projecting the columns that are used. Values stay **raw**. Materializes as a **view**. |
| 🥈 | `int_*` | `int_common`, `int_sales`, `int_purchases`, `int_finance`, `int_inventory` | only `mart_*` | Enriched business entity: joins, hierarchies, derived columns, enum translation. **Applies no business filters.** Materializes as a **table**. |
| 🥇 | `mart_*` | `mart_common`, `mart_sales`, `mart_purchases`, `mart_finance`, `mart_inventory` | Power BI + ad-hoc | A star schema ready to use: additive facts + descriptive dimensions. **This is where the BI connects.** Materializes as a **table** (except the movement fact, which is incremental). |

### 🥉 `stg_*` — Staging (bronze)

Minimal transformation: renames columns to snake_case and CASTs types (dates → `date`, numerics → `decimal`; ingestion watermarks such as `update_ts` stay timestamp). It is **1:1 in grain** (one staging row per raw row), but **projects only the columns that are used** — e.g., `inventory_movement_oinm` materializes 12 of OINM's ~110 columns — and may apply light text cleanup (trim / removal of control characters). The **values stay raw** — `DocStatus` remains `'O'`/`'C'`, `CANCELED` as `'N'`/`'Y'`/`'C'`. The translation of codes into business labels happens only in `int_*`. The subfolders (sales/purchases/master_data/items/finance) are just visual organization; the physical schema is a single one (`stg_sap`) and a staging model can be cross-domain (e.g., `business_partner_ocrd` serves sales, purchases, and finance).

**Attention — `doc_entry` is not unique in staging.** The transactional headers (OINV/OQUT/ORIN/ORDR/ODLN on the sales side; OPCH/OPOR/OPRQ on the purchases side) are ingested with the `incremental_append` strategy in raw, so the same `doc_entry` may appear in several rows (one per re-ingestion). Staging preserves this raw. The **defensive dedup** happens in `int_*` (see below). Do not query the staging of these headers expecting uniqueness by `doc_entry`.

### 🥈 `int_*` — Intermediate (silver)

A single enriched business entity — joins master_data, resolves hierarchies, computes derived columns, and translates enums. The **cross-domain building blocks** live in `int_common` (e.g., `partner`, `item`, `warehouse`, `employee`, `standardized_store`, `salesperson_bridge`). **Central policy:** `int_*` does NOT apply business filters — it preserves canceled, intercompany, hidden, and inactive warehouses. Each mart decides the whitelist.

**Defensive dedup.** Because `doc_entry` repeats in staging (incremental append), the transactional `int_*` models apply `row_number() over (partition by doc_entry order by _ingested_at desc)` and keep only `rn = 1` — the most recent version of each document. This is what guarantees that each document enters the facts exactly once.

#### Building-block architecture (sales and purchases)

The transactional domains do not build each fact directly from staging. They follow a **brick-per-type + consolidation via UNION ALL** pattern:

- **Bricks per document type** — each type has a pair of models (header + line) holding **all the logic** for enrichment, enum translation, and dedup. In sales there are bricks for `nf`, `orc` (quote), `dev` (return), and `ped` (order); in purchases for `nf`, `ped`, and `req` (requisition).
- **Consolidated models** — `sales_fiscal_documents` / `sales_fiscal_lines` (and `purchases_fiscal_documents` / `purchases_fiscal_lines`) are a **pure UNION ALL** of the bricks. They have no logic of their own; they just stack the types into a common format. **They are the direct sources of the facts.**

How to consume, going down from the mart to the int:

- Need **only one type** (e.g., outbound invoices only)? Consume the **brick directly** — it is cheaper and avoids scanning the other types.
- Need the **full funnel** (quote → order → invoice → return)? Use the **consolidated** model, which already brings all the types at the same grain.

#### Source traceability (funnel)

The chaining quote → order → invoice → return that appears in the sales and purchases domains is reconstructed from the `BaseEntry`/`BaseType` (and related) fields in SAP, which point to the source document of each line:

- **Sales** — `BaseType` takes values `13`/`15`/`17`/`23` (and `-1` when the line has no source). A return references the original invoice via `ActBaseEnt`; an order points to its target via `TrgetEntry`.
- **Purchases** — `BaseType` `22`/`18`/`1470000113` (and `-1` with no source).

It is this cross-cutting convention that underpins the funnel metrics; anyone who needs to follow a document's trail starts from these fields.

### 🥇 `mart_*` — Marts (gold)

Ready for BI. Star schemas with additive facts + descriptive dimensions. A reinforced Kimball pattern: **marts do not depend on other marts** — for example, `fact_accounts_receivable` replicates the filters of `fact_sales` but consumes `int_sales` directly, not `mart_sales`.

## Domains

| Domain | Schemas | What it covers |
|---|---|---|
| **common** | `int_common`, `mart_common` | Shared master data and dimensions (item, partner, employee, store, warehouse, calendar) and the `salesperson_bridge`. It has no fact of its own — it is just dimensions + bridge. |
| **sales** | `int_sales`, `mart_sales` | Revenue (outbound invoices and returns), the quote→order→invoice funnel, deliveries, freight, and sales goals. |
| **purchases** | `int_purchases`, `mart_purchases` | Inbound invoices for goods purchased for resale, and the requisition→order→invoice cycle. |
| **finance** | `int_finance`, `mart_finance` | Accounts receivable (`fact_accounts_receivable`), general-ledger / trial-balance journal entries (`finance_journal_entries`), and outbound payments (`finance_payments`). |
| **inventory** | `int_inventory`, `mart_inventory` | Current position (balance, turnover, coverage) and daily movement history. |

## Facts

| Fact | Schema | Business question | Grain | Key metrics |
|---|---|---|---|---|
| `fact_sales` | `mart_sales` | How much did Acme sell? | 1 row = item of an outbound invoice or return `(document_type, doc_entry, line_number)` | `quantity`, `line_total`, `total_taxes`, `total_cost`, `gross_profit` (additive, already signed) |
| `fact_goals` | `mart_sales` | What is each salesperson's sales goal per day? | 1 row = a salesperson's daily goal in a channel and store allocation `(channel, date, employee_code, original_goal_store)` | `daily_goal` |
| `fact_purchases` | `mart_purchases` | How much goods for resale did Acme buy? | 1 row = item of an inbound invoice `(document_type, doc_entry, line_number)` | `quantity`, `line_total`, `total_taxes`, `total_cost` (always positive) |
| `fact_accounts_receivable` | `mart_finance` | How much do customers owe me? | 1 row = an entire sales invoice `(document_type, doc_entry)`, not per installment | `total_amount`, `paid_amount`, `open_balance`, `installment_count*`, `payment_status` |
| `fact_inventory` | `mart_inventory` | How much inventory do I have right now, with turnover and coverage? | 1 row per `(item_code, warehouse_code)` — current snapshot | `inventory_quantity`, `inventory_value_at_list_price`, `giro_30/45/60d/year`, `cobertura_dias_*`, `days_without_outflow` |
| `fact_daily_inventory_movement` | `mart_inventory` | How did inventory move per day? | 1 row per `(date, item_code, warehouse_code)` — closed day | Flow: `inflow_quantity/saida/movimento`, `transacted_amount`; end-of-day state: `inventory_value_after_movement`, `quantity_after_movement` |

### Details worth knowing

- **`fact_sales`** — scope restricted to outbound invoices (`'invoice'`) and returns (`'return'`); quotes and orders are left out (they are intent, not a sale). Non-additive metrics (per-unit rates: `unit_price`, `discount_percentage`, `sap_margin`, etc.) always arrive positive and must be aggregated with a weighted average, never `SUM`. Canonical date = SAP's `CreateDate` (not the fiscal date).
- **`fact_goals`** — the planned side, the counterpart of `fact_sales`. The store enters the key (via `original_goal_store`, the raw text from the spreadsheet) because a salesperson can have parallel goals at different stores on the same day/channel. Restricted to 2025+ (the bridge dates the baseline from the 1st goal). A `daily_goal` that is NULL in the spreadsheet (vacation/leave) becomes 0. Note: the goal's `channel` (an administrative decision) is NOT the same as the sale's `load_kit` (the invoice's fiscal classification) — the divergence is useful information.
- **`fact_purchases`** — scope is only `usage_id = 3` (Commercial Purchase). Always positive: there is no purchase return in the fact (the SAP table OPDN is not ingested today → **gross** purchases). Freight to the supplier is already embedded in the price.
- **`fact_accounts_receivable`** — invoice grain (not installment), deliberate so as not to inflate the fact. Already-paid invoices remain in the fact (they enable ageing, DSO, and historical delinquency); whoever wants only "currently receivable" filters `open_balance > 0`.
- **`fact_inventory`** — valuation at **list price** (not cost), via the `current_price_list` var (currently 100). The 30/45/60d and YTD windows are counted from yesterday (D-1). An item with no price in the active list → NULL value (flags a master-data gap).
- **`fact_daily_inventory_movement`** — incremental with the `append` strategy (a closed day is immutable; OINM is an audit trail). The current day never enters — the "today" position is the responsibility of `fact_inventory`. Reconstructing the balance on a past date does not require a cumulative sum: the `Balance` (`inventory_value_after_movement`) is already cumulative.

### The finance domain in detail

Besides `fact_accounts_receivable`, the finance domain has two models worth knowing:

- **`finance_journal_entries`** (~3.3M rows, from JDT1 + OJDT) — the general ledger / trial balance at journal-entry-line grain. The `offset_account` is **polymorphic** (the counterpart can be another G/L account, a partner, etc.). An invariant guaranteed by a singular test: each line is **debit XOR credit**, never both nor neither.
- **`finance_payments`** (OVPM, ~66k) — outbound payments, with a mix of payment means (cash, transfer, check, etc.) consolidated per payment document.

## Shared dimensions (`mart_common`)

| Dimension | Grain | What it describes |
|---|---|---|
| `dim_date` | 1 record per date | Calendar from 2023-01-01 to 2035-12-31 (covers the lifetime of the data + long-term invoice due dates). Year/quarter/month/day, month and day names, ISO week, weekend, relative dates. Generated by native SQL (tally table), with no raw source. Each fact can have multiple relationships with it (issue, accrual, due date, payment). |
| `dim_item` | 1 record per `item_code` | Products with a commercial hierarchy (family → class → sub-class), `abc_curve`, unit, `unit_weight_kg`, `lead_time_days`, usage flags (`is_sellable`/`is_stockable`/`is_purchased`), and derived categorizations (`item_type`, `category_code`). The hierarchy and ABC curve have partial coverage — a state of SAP, not a bug. |
| `dim_partner` | 1 record per `partner_code` | Customers, suppliers, and leads in the same structure. `partner_type`, group, franchise, salesperson, `cpf_cnpj_normalized` + `cpf_cnpj_type` (cpf/cnpj/no document/irregular). Filters only partners visible in the BI. |
| `dim_employees` | 1 record per `employee_code` (SlpCode) | Stable identity of salespeople, managers, and B2B executives. Role and store (which change over time) are NOT here — they live in the `salesperson_bridge`. `hire_date` is an entry proxy derived from the 1st goal, **not** an HR admission date. |
| `dim_store` | 1 record per `store_code` | Store with a standardized commercial name, in the `uf-city` format (e.g., `rj-bonsucesso`), coming from the SharePoint mapping, with a fallback to the old SAP name. 3 known mergers cause distinct codes to share the same `store_name`. |
| `dim_warehouse` | 1 record per `warehouse_code` | The physical location of the goods, linkable to a store and a branch. A store can have several warehouses. ~57% are operational (factory, drop-shipping, marketplace) with no store linked. |

> The `salesperson_bridge` (SCD Type 2, in `int_common`) resolves which store each salesperson code was in during each period — it is the tie-breaking key for the goal × actual cross-reference. Use it by date: `WHERE date BETWEEN valid_from AND COALESCE(valid_to, '9999-12-31')`.
>
> **Breaking a circular reference:** the `salesperson_bridge` needs each salesperson's entry baseline, which comes from the 1st goal — but `sales_goals` already reads the bridge. To avoid closing a cycle in the DAG, there is a dedicated model, **`goal_name_entry`**, that extracts only the entry date from the goals and feeds the bridge. The bridge never reads `sales_goals` directly.

## Important conventions

### Canonical BI filters

The sales and purchases facts already apply Acme's official filters. **Do not duplicate this logic in Power BI** — consume the fact directly. The single source of truth is the macros in `macros/filtros_bi.sql`:

1. **Visible partner** — `partner_show_in_bi = 'yes'` (excludes ~16 internal/test partners out of ~72k). Historical references to excluded partners become `parceiro_desconhecido`. **Exception:** `document_show_in_bi = 'yes'` ("force display") is a **global override** that pierces this and the other filters (see note below).
2. **Intercompany** — excludes `group_code = 111` (sales between units of Acme itself), **except** `branch_id = 9` (the group's manufacturing unit, the real factory/supplier). In purchases there is no exception for branch 9 (counting the other side would create double counting).
3. **Fiscal usage** — sales (invoices): `usage_id IN (9,10,20,22,37,46,56)` applied to the **line's** `usage_id` (`INV1/RIN1.Usage`), replicating the legacy view vw_ranking_vendas_legada; the **return** is a separate case and filters by the **header** (`main_usage_id = 24`). Purchases: only `usage_id = 3`. **Fiscal usage lives at two levels** (header `MainUsage` / line `Usage`) and each document type uses a **fixed** level — **there is no COALESCE/fallback between them**. A sale filters by the line on purpose: the header's `MainUsage` frequently comes NULL (~36% of invoices, ~95% of quotes, ~15% of returns), so the line gives broader coverage.
4. **Canceled** — in **purchases it IS a filter** (`canceled = 'no'`); in **sales it is NOT a filter** (see the sign below).

> **`document_show_in_bi`** (U_SHOW_IN_BI of OINV/ORIN) means "force display" — the default 'N' is neutral (it does not hide). It is not a cut-off filter; it is a **global override**: `documento='yes'` pierces every BI filter (partner, intercompany, fiscal usage, canceled). The **`triangulation`** field, on the other hand (85% in "to confirm", the default state; filtering it would drop 99% of invoices), **is not a filter** — it is exposed only as an attribute.

### The return sign

In sales, returns and reversals arrive with their **additive metrics already negated** in the fact. The rule: original invoice (+1), reversal invoice (-1), return (-1). Result: `SUM(line_total)` in Power BI already delivers the net amount (invoice + canceled − reversal − return), **with no CASE WHEN in the BI**. Since the date is `CreateDate`, the invoice and the reversal can fall in different months — the net amount only closes by summing over the entire lifetime, and a closed month can change retroactively (the same behavior as the official BI).

A return only enters negated if it is **valid**: a canceled/reversed return (`dev` with `canceled <> 'no'`) is **excluded** from the fact, so as not to introduce noise into the closing. In other words, not every `dev` enters with −1 — only the effective ones.

### The "Sales R$" KPI

Use `SUM(line_total)` — product revenue, **excluding freight**. The freight charged to the customer is in the header (`sales_fiscal_documents.freight_amount`, expense code 1 of INV3) in case you need to look it up separately — it is not broken down per line in `fact_sales`.

### Other conventions

- **`var current_price_list = 100`** — defines which price list values the inventory in `fact_inventory`. Change it in `dbt_project.yml` when the active list changes.
- **Indexes** — every dim and fact has a `post_hook` for a **single clustered index** on the PK (the `clustered_unique_index` macro). Preventive nonclustered indexes were removed by architectural decision; a focused one is added only when there is a slow query proven by an execution plan.
- **Schema naming** — the `+schema` from `dbt_project.yml` is used **literally** (overridden in `generate_schema_name`), without the target prefix. That is why `stg_sap`, `int_sales`, `mart_common`, etc. come out exact.
- **The `document_type` discriminator** — SAP's DocEntry is not globally unique, only within each type. The functional key of the facts is `(document_type, doc_entry[, line_number])`; the surrogate `document_id` = `'<type>-<doc_entry>'` (e.g., `nf-368971`).
- **Defensive dedup** — transactional headers enter via `incremental_append`, so `doc_entry` repeats in staging; `int_*` breaks the tie with `row_number() ... order by _ingested_at desc` and keeps `rn = 1`. Anyone querying the raw staging of these headers needs to apply the same tie-breaker.
- **Boolean flags** materialized as the strings `'yes'`/`'no'` (validated with `accepted_values`). Descriptive text (item, partner, group names) stored in lowercase.
- **Tests** — `not_null` + `unique` on simple PKs; `unique_combination_of_columns` on composite keys; `accepted_values` on enums; `relationships` for referential integrity.

## Where to find more

- **Business rules (the "why"):** each fact and dimension has an **extensive prose description** in its `schema.yml`, explaining every filter and decision — not just the SQL. Start with the `description`s before opening the `.sql`. There are **several reusable doc blocks by theme** that consolidate repeated concepts — filters (`sales_filter_policy`), defensive dedup (`sales_defensive_dedup`, `purchases_defensive_dedup`), source traceability (`sales_source_traceability`, `purchases_source_traceability`), fiscal usage (`sales_fiscal_usage_concept`), the type discriminator (`sales_document_type_discriminator`), enum translation (`sales_header_enum_translation`), and the document cycle (`purchases_document_cycle`).
- **Origin of the SAP tables:** a table-by-table reference in the documentation of the SAP ingestion pipeline.
- **Observability:** Elementary (a dedicated `elementary` schema) monitors execution and test quality, outside the business layers.
- **Macros and conventions:** `macros/filtros_bi.sql` (canonical filters), `macros/indices.sql` (indexes), plus normalization utilities (`digits_only`, `normalize_brazilian_decimal`).

{% enddocs %}