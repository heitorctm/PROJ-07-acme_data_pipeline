{{ config(post_hook=clustered_unique_index(['doc_entry', 'installment_number'])) }}
-- outbound invoice installments (INV6) — the customer's payment plan.
-- granularity: one line per (doc_entry, installment_number).
-- consumed by mart_finance.fact_accounts_receivable (aggregating at the invoice level).
--
-- translates enums:
--   installment_status: 'O' (open) / 'C' (closed).
--   a "closed" installment may be paid (paid_amount = installment_amount) or never
--   paid (canceled/reversed invoice — installment_status='C' + paid_amount=0).
--
-- exposes open_balance to avoid recomputation downstream (installment_amount - paid_amount).
select
    p.doc_entry,
    p.installment_number,
    p.due_date,
    p.installment_amount,
    p.paid_amount,
    p.installment_amount - p.paid_amount                              as open_balance,
    case p.installment_status
        when 'O' then 'open'
        when 'C' then 'closed'
        else lower(p.installment_status)
    end                                                         as installment_status,
    p._ingested_at
from {{ ref('sales_invoice_installments_inv6') }} p
