{% docs purchases_filter_policy %}
**Filter policy:** purchases `int`-layer models **do not apply business filters**.
Canceled documents, intercompany, hidden from BI — everything is preserved. Each consuming mart
defines its whitelist according to the use case (e.g., total purchased per supplier excludes
canceled ones; the req→ped→nf funnel analysis includes canceled ones to measure the drop-off rate).

The `canceled`, `group_code` (to detect intercompany) fields are exposed for
downstream filtering.
{% enddocs %}


{% docs purchases_document_cycle %}
**Purchases cycle in SAP B1:** the standard flow is **REQUISITION → ORDER → INBOUND INVOICE**.

- **Requisition (`OPRQ`):** internal request ("I need to buy X"). There is no supplier
  assigned yet — only the user (`UserSign`) who registered it. Optional document — Acme uses it
  little (only ~1,300 requisitions). Has a dedicated `external_ticket` (reference to the ticketing
  system).
- **Purchase order (`OPOR`):** already has the chosen supplier and negotiated value. It may
  originate from a requisition (via BaseEntry/BaseType) or be created directly.
- **Inbound invoice (`OPCH`):** final fiscal document, records the receipt of goods. It may
  originate from an order (via BaseEntry/BaseType=22) or be direct. Most invoices at Acme are
  registered directly, without a prior order.

**Type-exclusive attributes in the consolidated fact:**

| Attribute | nf | ped | req |
|---|---|---|---|
| `supplier_code` | ✓ | ✓ | NULL (no supplier yet) |
| `ledger_transaction_id` | ✓ | NULL | NULL |
| `document_total`, `total_taxes`, `gross_profit` | ✓ | partial | NULL |
| `series_code`, `series_number`, `payment_method` | ✓ | NULL | NULL |
| `store_code`, `store_name` | ✓ | NULL | NULL |
| `user_id`, `user_name` | NULL (not extracted) | ✓ | ✓ |
| `external_ticket` | NULL | NULL | ✓ |
| `accrual_date`, `due_date` | ✓ | NULL | NULL |
| `creation_date` | NULL (not extracted from OPCH) | ✓ | ✓ |
{% enddocs %}


{% docs purchases_defensive_dedup %}
**Defensive dedup:** the tables in `raw_sap` (`OPCH`, `OPOR`, `OPRQ`) use the `incremental_append`
ingestion strategy, which keeps multiple versions of the same `doc_entry` over time.
To guarantee 1 record per document in `int`, we apply:

```sql
row_number() over (partition by doc_entry order by _ingested_at desc) as rn
-- ... filters rn = 1
```

Selects the most recent version per document. Defensive — the upstream pipeline should
guarantee uniqueness, but we keep the safeguard in case of an ingestion failure.
{% enddocs %}


{% docs purchases_source_traceability %}
**Source traceability in purchases:** link between stages of the req→ped→nf cycle via
`BaseEntry` + `BaseType` (numeric) at the line level.

| BaseType | SAP Table | Case |
|---:|---|---|
| 22 | OPOR | Invoice generated from an order (few cases at Acme) or an order copied from another order |
| 18 | OPCH | Invoice generated from another invoice (supplementary, fiscal retransmission) |
| 1470000113 | OPRQ | Order from a requisition (rare at Acme) |
| -1 | — | Document with no source (created directly) |

**Requisition (PRQ1) has no source** — it is always the start of the chain. `source_doc_entry` and
`source_document_type` are NULL for `document_type = 'requisition'`.
{% enddocs %}
