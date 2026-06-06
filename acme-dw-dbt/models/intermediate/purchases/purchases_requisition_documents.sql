{{ config(post_hook=clustered_unique_index(['doc_entry'])) }}
-- purchase requisition header (OPRQ) enriched with branch and user
-- grain: one record per doc_entry (after defensive dedup)
-- consumed by purchases_fiscal_documents via UNION ALL
-- OPRQ has no assigned supplier (it is only set on the order) — all partner
-- fields come through NULL. It also has no totals, series, payment method, journal entry.
-- It has an external_ticket exclusive to requisitions.
with req_dedup as (
    select *,
        row_number() over (partition by doc_entry order by _ingested_at desc) as rn
    from {{ ref('purchase_requisition_oprq') }}
),
req as (
    select
        doc_entry,
        requisition_number               as document_number,
        issue_date,
        cast(null as date)              as accrual_date,
        cast(null as date)              as due_date,
        creation_date,
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
        cast(null as nvarchar(50))      as supplier_code,
        branch_id,
        cast(null as smallint)          as series_code,
        cast(null as int)               as series_number,
        cast(null as nvarchar(50))      as payment_method,
        cast(null as int)               as ledger_transaction_id,
        user_id,
        cast(null as nvarchar(50))      as store_code,
        cast(null as decimal(20, 6))    as document_total,
        cast(null as decimal(20, 6))    as total_taxes,
        cast(null as decimal(20, 6))    as gross_profit,
        external_ticket,
        external_ticket_date,
        _ingested_at
    from req_dedup where rn = 1
)
select
    'req-' + cast(d.doc_entry as varchar)                as document_id,
    'requisition'                                                as document_type,
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
    cast(null as varchar(200))                           as supplier_name,
    cast(null as int)                                    as group_code,
    cast(null as varchar(200))                           as group_name,
    cast(null as varchar(10))                            as partner_show_in_bi,
    cast(null as varchar(50))                            as cpf_cnpj_official,
    cast(null as varchar(50))                            as cpf_cnpj_normalized,
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
    cast(null as varchar(255))                           as store_name,
    d.document_total,
    d.total_taxes,
    d.gross_profit,
    d.external_ticket,
    d.external_ticket_date,
    d._ingested_at
from req                                                 d
left join {{ ref('branch_obpl') }}             f  on f.branch_id        = d.branch_id
left join {{ ref('user') }}                 u  on u.user_id       = d.user_id
