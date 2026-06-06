{{ config(post_hook=clustered_unique_index(['document_type', 'doc_entry']), tags=['fact']) }}
-- fact_accounts_receivable — invoice granularity (1 row per outbound fiscal document).
--
-- ## granularity: why invoice and not installment
--
-- the installment in SAP (INV6) lives at the document level, not the line. Building
-- installment-level granularity would inflate the fact with no managerial benefit — the
-- business question is "how much does customer X owe me" and "what is the status of invoice Y",
-- which is answered at the invoice level.
--
-- aggregated installment metrics:
--   total_amount             = sum(installment_amount)  — total issued
--   paid_amount              = sum(paid_amount)
--   open_balance             = total_amount - paid_amount
--   installment_count        = count(*)
--   paid_installment_count   = count where paid_amount >= installment_amount
--   first_due_date           = min(due_date)
--   last_due_date            = max(due_date)
--
-- payment_status (derived):
--   'paid'     paid_amount >= total_amount
--   'partial'  0 < paid_amount < total_amount
--   'open'     paid_amount = 0
--
-- ## scope
--
-- same whitelist as fact_sales, applied DIRECTLY from the int (mart_finance
-- does not depend on mart_sales — follows the Kimball "independent marts" pattern).
-- canonical BI filters (canceled, partner_show_in_bi, intercompany) via a
-- shared macro + fiscal-usage whitelist. GLOBAL OVERRIDE: an invoice flagged
-- document_show_in_bi='yes' ("force display") enters bypassing these filters
-- (keeping only the invoice scope + installment requirement). Same rule as fact_sales.
--
-- ## historical scope
--
-- all in-scope invoices enter (with and without balance). The "only with balance > 0"
-- filter lives in the BI. This enables ageing analyses, delinquency rate by cohort,
-- average payment per customer, etc.
with aggregated_installments as (
    select
        doc_entry,
        sum(installment_amount)                                              as total_amount,
        sum(paid_amount)                                                 as paid_amount,
        sum(open_balance)                                            as open_balance,
        count(*)                                                        as installment_count,
        sum(case when paid_amount >= installment_amount then 1 else 0 end)    as paid_installment_count,
        sum(case when paid_amount = 0 then 1 else 0 end)                 as open_installment_count,
        sum(case when paid_amount > 0 and paid_amount < installment_amount
                 then 1 else 0 end)                                     as partial_installment_count,
        min(due_date)                                            as first_due_date,
        max(due_date)                                            as last_due_date
    from {{ ref('sales_installments') }}
    group by doc_entry
),

-- scope: only invoices (not returns) with at least one commercial sales
-- line — replicates the canonical BI filters from fact_sales.
valid_docs as (
    select distinct
        d.document_type,
        d.doc_entry,
        d.document_number,
        d.creation_date                                                  as date,
        d.customer_code                                                as partner_code,
        nullif(d.salesperson_code, -1)                                   as employee_code,
        d.store_code,
        d.load_kit,
        d.presale_channel
    from {{ ref('sales_fiscal_documents') }} d
    inner join {{ ref('sales_fiscal_lines') }} l
        on l.document_type = d.document_type
       and l.doc_entry      = d.doc_entry
    where d.document_type = 'invoice'
      -- "force display" is a GLOBAL OVERRIDE (same rule as fact_sales): an invoice flagged
      -- document_show_in_bi='yes' enters regardless of partner/intercompany/fiscal
      -- usage. It keeps the invoice scope (accounts receivable is invoice-only) and the
      -- installment requirement (inner join below). See _vendas__docs.md (doc block vendas_politica_filtros).
      and (
          d.document_show_in_bi = 'yes'
          or (
              1=1
              and l.usage_id in {{ sales_fiscal_usage_whitelist() }}
              {{ apply_sales_bi_filters('d') }}
          )
      )
)

select
    -- granularity key
    d.document_type,
    d.doc_entry,
    d.document_number,

    -- dimension keys
    d.date,
    d.partner_code,
    d.employee_code,
    d.store_code,
    p.first_due_date,
    p.last_due_date,

    -- descriptive document attributes
    d.load_kit,
    d.presale_channel,

    -- additive metrics
    p.total_amount,
    p.paid_amount,
    p.open_balance,
    p.installment_count,
    p.paid_installment_count,
    p.open_installment_count,
    p.partial_installment_count,

    -- aggregated status
    case
        when p.paid_amount >= p.total_amount                  then 'paid'
        when p.paid_amount > 0                                then 'partial'
        else                                                      'open'
    end                                                             as payment_status

from valid_docs d
inner join aggregated_installments p on p.doc_entry = d.doc_entry
