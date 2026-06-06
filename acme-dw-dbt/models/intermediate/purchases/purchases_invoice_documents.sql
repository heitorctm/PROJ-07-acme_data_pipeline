{{ config(post_hook=clustered_unique_index(['doc_entry'])) }}
-- inbound invoice header (OPCH) enriched with supplier, branch and store
-- grain: one record per doc_entry (after defensive dedup)
-- consumed by purchases_fiscal_documents via UNION ALL
-- OPCH in the current raw layer carries neither user_id nor creation_date — these stay NULL in the canonical schema
with nf_dedup as (
    select *,
        row_number() over (partition by doc_entry order by _ingested_at desc) as rn
    from {{ ref('purchase_invoice_opch') }}
),
nf as (
    select
        doc_entry,
        invoice_number                       as document_number,
        issue_date,
        accrual_date,
        due_date,
        cast(null as date)              as creation_date,
        updated_date,
        case document_status
            when 'O' then 'open'
            when 'C' then 'closed'
            else lower(document_status)
        end                             as document_status,
        case canceled
            when 'N' then 'no'
            when 'Y' then 'canceled'
            when 'C' then 'reversal'
            else lower(canceled)
        end                             as canceled,
        supplier_code,
        branch_id,
        series_code,
        series_number,
        lower(payment_method)         as payment_method,
        ledger_transaction_id,
        cast(null as int)               as user_id,
        store_code,
        document_total,
        total_taxes,
        gross_profit,
        cast(null as nvarchar(50))      as external_ticket,
        cast(null as date)              as external_ticket_date,
        _ingested_at
    from nf_dedup where rn = 1
)
select
    'nf-' + cast(d.doc_entry as varchar)                 as document_id,
    'invoice'                                                 as document_type,
    d.doc_entry,
    d.document_number,
    d.issue_date,
    d.accrual_date,
    d.due_date,
    d.creation_date,
    d.updated_date,
    d.document_status,
    d.canceled,
    d.supplier_code,
    lower(pn.partner_name)                              as supplier_name,
    pn.group_code,
    lower(pn.group_name)                                 as group_name,
    pn.show_in_bi                                       as partner_show_in_bi,
    pn.cpf_cnpj_official,
    pn.cpf_cnpj_normalized,
    d.branch_id,
    lower(f.branch_name)                                 as branch_name,
    lower(f.nomenclature)                                as branch_nomenclature,
    d.series_code,
    d.series_number,
    d.payment_method,
    d.ledger_transaction_id,
    d.user_id,
    u.user_login,
    lower(u.user_name)                                as user_name,
    d.store_code,
    lower(l.store_name)                                   as store_name,
    d.document_total,
    d.total_taxes,
    d.gross_profit,
    d.external_ticket,
    d.external_ticket_date,
    d._ingested_at
from nf                                                  d
left join {{ ref('partner') }}                pn on pn.partner_code = d.supplier_code
left join {{ ref('branch_obpl') }}             f  on f.branch_id        = d.branch_id
left join {{ ref('user') }}                 u  on u.user_id       = d.user_id
left join {{ ref('store') }}                    l  on l.store_code      = d.store_code
