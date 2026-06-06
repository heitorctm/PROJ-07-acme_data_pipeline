{{ config(post_hook=clustered_unique_index(['document_type', 'doc_entry'])) }}
-- freight aggregated per document (invoice + return). granularity: 1 line per
-- (document_type, doc_entry).
--
-- replicates the V3 rule (vw_ranking_vendas_legada) that joins INV3 with
-- ExpnsCode = 1. this is the "freight charged to the customer" — the only
-- additional expense that has historically been part of revenue in Acme's dashboard.
--
-- other expenses (expense_code 3 'others', 5 'ipi') exist but have
-- residual volume and V3 does not include them — kept for compatibility.
--
-- consumed by sales_invoice_documents and sales_return_documents to expose
-- freight_amount on the header. fact_sales allocates this freight across the
-- document lines in proportion to line_total.
select
    document_type,
    doc_entry,
    sum(expense_amount)                                          as freight_amount
from {{ ref('sales_expenses') }}
where expense_code = 1
group by document_type, doc_entry
