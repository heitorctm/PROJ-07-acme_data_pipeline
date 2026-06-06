{% docs sales_filter_policy %}
**Filter policy:** sales `int`-layer models **do not apply business filters**
as a general rule. Canceled documents, intercompany (group 111, except branch 9 —
"contribution"), hidden from BI (`show_in_bi = 'no'`), with internal-transfer `usage_id`
(5), without item, etc. — **everything is preserved**. Each consuming mart defines its whitelist
according to the use case:

- Sales ranking (`fact_sales`): `usage_id ∈ {9, 10, 20, 22, 37, 46, 56}`. Canceled/reversed invoices enter with opposite signs (matching the official BI); **a canceled/reversed return is excluded** (only `dev` with `canceled='no'`) — the pair would net to zero, but, dated by `CreateDate`, it would leak across months. See `regra_data_venda.md` §1 and `fact_sales.sql`.
- Fiscal reconciliation: uses all usages and accounts for reversals.
- Funnel analysis: includes quotes and canceled orders (to measure loss rate).

The `document_show_in_bi`, `partner_show_in_bi`, `canceled`, `group_code` fields are
exposed for downstream filtering.

**About `document_show_in_bi` (U_SHOW_IN_BI from OINV/ORIN):** it is a "manual force-display
flag" (exceptional case). Data inspection in May/2026: 197,510 invoices with `'N'`, 56 with
`'S'` and 355 NULL — `'N'` is the operational default (it does NOT mean "hide") and all of the
real revenue sits in it. That is why the field cannot be used as the SOLE filter (`WHERE
document = 'yes'` would drop 99.98% of revenue). In the **marts** it enters as a **GLOBAL
OVERRIDE** in the fact's WHERE clause (NOT in the visibility macro): `document_show_in_bi = 'yes' OR
(normal filters)` — the flag bypasses ALL filters (partner, intercompany, fiscal usage,
canceled), not just the partner one. It only ADDS manually flagged documents, without removing
anything (it mirrors the BI; confirmed cases: invoice 176286 Jan/2026 hidden partner, and return 4055
May/2026 fiscal usage 36). On `partner_show_in_bi` (OCRD) the flag is the primary visibility
filter — 99.98% of partners are set to `'S'`.

**There are no exceptions today:** neither `triangulation` nor `show_in_bi` is filtered in
int models. The legacy view `vw_ranking_vendas_legada` (which validated the BI numbers) also does not
filter by these columns — 85% of SAP invoices have `triangulation = 'C'` (operational default,
not a real pending item), and `U_SHOW_IN_BI` in OINV is a manual "force display" flag used rarely.

Before the refactor, `sales_invoice_documents` had `where triangulation = 'N'`. Removed
because it dropped 99% of real revenue with no analytical benefit.
{% enddocs %}


{% docs sales_defensive_dedup %}
**Defensive dedup:** the tables in `raw_sap` (`OINV`, `OQUT`, `ORIN`, `ORDR`) use the
`incremental_append` ingestion strategy, which keeps multiple versions of the same `doc_entry` over
time (one per SAP update). To guarantee 1 record per document in `int`, we
apply:

```sql
row_number() over (partition by doc_entry order by _ingested_at desc) as rn
-- ... filters rn = 1
```

This selects the most recent version per document. It is **defensive** because the upstream pipeline
should guarantee this, but we keep the safeguard in case of an ingestion failure (e.g., manual
re-run of a period).
{% enddocs %}


{% docs sales_source_traceability %}
**Source traceability:** SAP B1 exposes the document chain via two columns at the line
level:

- `source_doc_entry` (`BaseEntry`): `DocEntry` of the document that originated this line.
- `source_document_type` (`BaseType`): numeric code for the type of the source document.

Known `BaseType` values in sales:

| BaseType | SAP Table | Meaning |
|---:|---|---|
| 13 | OINV | Outbound invoice — used for supplementary/retransmission invoices and as the reference to the original invoice in returns |
| 15 | ODLN | Delivery |
| 17 | ORDR | Sales order |
| 23 | OQUT | Quote |
| -1 | — | Document with no source (created directly) |

Special cases:
- **Return** has `effective_source_doc_entry` (`ActBaseEnt` from RIN1) — points to the original
  invoice that was returned, even when `BaseEntry` points to another document.
- **Order** has `doc_entry_sales_invoice` (`TrgetEntry` from RDR1) — target: the invoice generated from
  this order line.
{% enddocs %}


{% docs sales_fiscal_usage_concept %}
**Concept of "fiscal usage" in SAP B1 Brazil:** every fiscal document must be classified
by a fiscal purpose — "Sale", "Bonus", "Internal transfer", "Return",
"Use and consumption", etc. These codes live in the `OUSG` catalog (table `fiscal_usage_ousg`) and are
essential for mandatory fiscal reports (SPED, Sintegra, GIA), tax assessment
(ICMS, PIS, COFINS) and mix analysis.

**Two levels of fiscal usage:**

- **Header:** classifies the entire document. Comes from the `MainUsage` column in the fiscal
  extension (`INV12`/`QUT12`/`RIN12`). Exposed as `main_usage_id` in `_documentos` and propagated to
  the `_linhas` via join.
- **Line:** each item can have its own fiscal usage. Lives in `INV1.Usage` / `QUT1.Usage` /
  `RIN1.Usage` (column `usage_id` on the lines). An invoice can mix sale + bonus +
  transfer in the same operation.

**Common usages at Acme** (labels per the `OUSG` catalog, the source of truth; the sales whitelist
`usage_id IN (9, 10, 20, 22, 37, 46, 56)` is the one that feeds `fact_sales`):

| `usage_id` | Description |
|---:|---|
| 9 | Sale of own product |
| 10 | Sale of goods acquired from third parties (resale) |
| 20 | Sale with future delivery |
| 22 | Sale to end consumer |
| 37 | Sale by order |
| 46 | Sale with Suframa |
| 56 | Sale by order to end consumer |
| 5 | Internal transfer (not a sale) |
| 24 | Return of goods (in the return header, `main_usage_id`) |

**Coverage in `raw_sap`:**
- ~36% of invoices have `MainUsage = NULL` (real SAP state, not a model defect).
- ~95% of quotes have `MainUsage = NULL` (quotes are preliminary).
- ~15% of returns have `MainUsage = NULL`.

When `main_usage_id` is NULL, the fiscal filter should use the line's `usage_id` (greater coverage).

**Orders have no fiscal extension** in SAP B1 standard — `usage_id` and `main_usage_id` are
NULL for `document_type = 'order'`.
{% enddocs %}


{% docs sales_document_type_discriminator %}
**`document_type` discriminator:** column that identifies the record's origin in the consolidated
facts built via UNION ALL. It exists because SAP's `DocEntry` is **not globally unique** —
it is unique only within each document type. The functional key of the facts is
`(document_type, doc_entry)` or `(document_type, doc_entry, line_number)`.

**Values in sales:** `'invoice'` (outbound invoice), `'quote'` (quote), `'return'` (invoice return),
`'order'` (sales order).

**Surrogate key:** `document_id` is built as `<document_type>-<doc_entry>` (e.g., `nf-123456`)
to serve as a unique primary key at the document level.
{% enddocs %}


{% docs sales_header_enum_translation %}
**Translation of SAP enums to lowercase text** applied to the sales
headers:

| SAP Field | Original value | Translated value |
|---|---|---|
| `DocStatus` (document_status) | `'O'` / `'C'` | `'open'` / `'closed'` |
| `CANCELED` (canceled) | `'N'` / `'Y'` / `'C'` | `'no'` / `'canceled'` / `'reversal'` |
| `U_LOAD_KIT` (load_kit) | `'N'` / `'S'` / `'P'` | `'retail'` / `'wholesale'` / `NULL` |
| `U_FINANCE_VALIDATED` (finance_validated) | `'N'` / `'S'` / `'P'` | `'not validated'` / `'validated'` / `'pending'` |
| `U_SHOW_IN_BI` (show_in_bi) | `'S'` / `'N'` | `'yes'` / `'no'` |
| `U_PRESALE` (presale_channel) | `'N'`/`'P'`/`'PS'`/`'PD'`/... | `'no'`/`'crm'`/`'crm steel frame'`/`'crm drywall'`/... |
| `U_TRIANGULATION` (triangulation) | `'C'` / `'S'` / `'N'` | `'to confirm'` / `'yes'` / `'no'` — exposed as an attribute, **no filter** (see filter policy) |

`payment_method` (PeyMethod) is only converted to lowercase (free text, no code
mapping).
{% enddocs %}
