{{ config(post_hook=clustered_unique_index(['document_type', 'doc_entry', 'line_number'])) }}
-- additional expenses from outbound invoices (INV3) and returns (RIN3) unified
-- granularity: one line per (document_type, doc_entry, line_number)
-- enriched with the expense name via OEXD (freight, insurance, IPI, etc.)
select
    'invoice'                                            as document_type,
    d.doc_entry,
    d.line_number,
    d.expense_code,
    lower(o.expense_name)                           as expense_name,
    d.expense_amount,
    d._ingested_at
from {{ ref('sales_invoice_expenses_inv3') }}            d
left join {{ ref('additional_expense_oexd') }}       o on o.expense_code = d.expense_code

union all

select
    'return'                                           as document_type,
    d.doc_entry,
    d.line_number,
    d.expense_code,
    lower(o.expense_name)                           as expense_name,
    d.expense_amount,
    d._ingested_at
from {{ ref('sales_return_expenses_rin3') }}           d
left join {{ ref('additional_expense_oexd') }}       o on o.expense_code = d.expense_code
