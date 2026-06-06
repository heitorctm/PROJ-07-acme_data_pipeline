{{ config(post_hook=clustered_unique_index(['doc_entry'])) }}
-- sales order header (ORDR) enriched with partner, salesperson and branch
-- granularity: one record per doc_entry (after defensive dedup)
-- consumed by sales_fiscal_documents via UNION ALL
-- ORDR in the current raw layer does not carry series_code, series_number, payment_method,
-- ledger_transaction_id, header_discount, store_code, load_kit, presale_channel,
-- finance_validated, show_in_bi — these stay NULL in the canonical schema
with orders_dedup as (
    select *,
        row_number() over (partition by doc_entry order by _ingested_at desc) as rn
    from {{ ref('sales_order_ordr') }}
),
orders as (
    select
        doc_entry,
        order_number                   as document_number,
        issue_date,
        cast(null as date)              as accrual_date,
        expected_delivery_date,
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
        customer_code,
        salesperson_code,
        branch_id,
        cast(null as int)               as series_code,
        cast(null as varchar(50))       as series_number,
        cast(null as varchar(50))       as payment_method,
        cast(null as int)               as ledger_transaction_id,
        document_total,
        gross_profit,
        cast(null as decimal(20, 6))    as header_discount,
        total_taxes,
        cast(null as varchar(50))       as store_code,
        cast(null as varchar(50))       as presale_channel,
        cast(null as varchar(50))       as load_kit,
        cast(null as varchar(50))       as finance_validated,
        cast(null as varchar(10))       as show_in_bi,
        cast(null as varchar(20))       as triangulation,
        _ingested_at
    from orders_dedup where rn = 1
)
select
    'ped-' + cast(d.doc_entry as varchar)                as document_id,
    'order'                                                as document_type,
    d.doc_entry,
    d.document_number,
    d.issue_date,
    d.accrual_date,
    d.expected_delivery_date,
    d.creation_date,
    d.updated_date,
    d.document_status,
    d.canceled,
    d.customer_code,
    lower(pn.partner_name)                              as partner_name,
    lower(pn.partner_type)                              as partner_type,
    pn.group_code,
    lower(pn.group_name)                                 as group_name,
    lower(pn.franchise_name)                              as franchise_name,
    pn.cpf_cnpj_official,
    pn.cpf_cnpj_normalized,
    pn.show_in_bi                                       as partner_show_in_bi,
    d.salesperson_code,
    lower(vd.salesperson_name)                              as salesperson_name,
    vd.salesperson_store_code,
    lower(vd.salesperson_store_name)                         as salesperson_store_name,
    d.branch_id,
    lower(f.branch_name)                                 as branch_name,
    lower(f.nomenclature)                                as branch_nomenclature,
    d.store_code,
    cast(null as varchar(255))                           as document_store_name,
    -- an order has no store on the document; it always falls back to the salesperson store
    lower(vd.salesperson_store_name)                         as display_store_name,
    d.series_code,
    d.series_number,
    d.payment_method,
    d.ledger_transaction_id,
    d.document_total,
    d.gross_profit,
    d.header_discount,
    d.total_taxes,
    cast(0 as decimal(20, 6))                            as freight_amount,
    coalesce(d.presale_channel, pn.presale_channel)        as presale_channel,
    d.load_kit,
    d.finance_validated,
    d.show_in_bi                                        as document_show_in_bi,
    d.triangulation,
    d._ingested_at
from orders                                              d
left join {{ ref('partner') }}                pn on pn.partner_code    = d.customer_code
left join {{ ref('sales_store_salesperson') }}    vd on vd.salesperson_code    = d.salesperson_code
left join {{ ref('branch_obpl') }}             f  on f.branch_id           = d.branch_id
