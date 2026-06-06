{{ config(post_hook=clustered_unique_index(['doc_entry'])) }}
-- outbound invoice return header (ORIN) enriched with partner, salesperson, branch and store
-- granularity: one record per doc_entry (after defensive dedup)
-- consumed by sales_fiscal_documents via UNION ALL
-- ORIN does not carry accrual_date or ledger_transaction_id — these stay NULL in the canonical schema
with returns_dedup as (
    select *,
        row_number() over (partition by doc_entry order by _ingested_at desc) as rn
    from {{ ref('sales_return_orin') }}
),
returns as (
    select
        doc_entry,
        return_number                as document_number,
        issue_date,
        cast(null as date)              as accrual_date,
        cast(null as date)              as expected_delivery_date,
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
        series_code,
        series_number,
        lower(payment_method)         as payment_method,
        cast(null as int)               as ledger_transaction_id,
        document_total,
        gross_profit,
        header_discount,
        total_taxes,
        store_code,
        case presale_channel
            when 'N'  then 'no'
            when 'P'  then 'crm'
            when 'PS' then 'crm steel frame'
            when 'PD' then 'crm drywall'
            when 'PP' then 'crm floors'
            when 'PA' then 'crm acoustic'
            when 'PE' then 'crm frames'
            when 'PQ' then 'crm mortar'
            when 'I'  then 'internal (google)'
            else lower(presale_channel)
        end                             as presale_channel,
        case load_kit
            when 'N' then 'retail'
            when 'S' then 'wholesale'
            when 'P' then 'unclassified'
            else lower(load_kit)
        end                             as load_kit,
        case finance_validated
            when 'N' then 'not validated'
            when 'S' then 'validated'
            when 'P' then 'pending'
            else lower(finance_validated)
        end                             as finance_validated,
        case show_in_bi
            when 'S' then 'yes'
            when 'N' then 'no'
            else lower(show_in_bi)
        end                             as show_in_bi,
        cast(null as varchar(20))       as triangulation,
        _ingested_at
    from returns_dedup where rn = 1
),

-- some old U_Store values came in as a text name ('BONSUCESSO', 'CENTRO')
-- instead of a code ('02', '06'). we resolve it in the int layer: if the value
-- matches Code directly, use Code; if it matches Name, swap it for Code; otherwise NULL.
store_resolver as (
    select
        l.store_code           as entry_store_code,
        l.store_code           as resolved_store_code
    from {{ ref('store') }} l
    union all
    select
        l.store_name             as entry_store_code,
        l.store_code           as resolved_store_code
    from {{ ref('store') }} l
)
select
    'dev-' + cast(d.doc_entry as varchar)                as document_id,
    'return'                                                as document_type,
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
    lr.resolved_store_code                             as store_code,
    lower(ld.store_name)                                  as document_store_name,
    lower(coalesce(ld.store_name, vd.salesperson_store_name)) as display_store_name,
    d.series_code,
    d.series_number,
    d.payment_method,
    d.ledger_transaction_id,
    d.document_total,
    d.gross_profit,
    d.header_discount,
    d.total_taxes,
    coalesce(fr.freight_amount, 0)                          as freight_amount,
    coalesce(d.presale_channel, pn.presale_channel)        as presale_channel,
    d.load_kit,
    d.finance_validated,
    d.show_in_bi                                        as document_show_in_bi,
    d.triangulation,
    d._ingested_at
from returns                                             d
left join store_resolver                       lr on lr.entry_store_code = d.store_code
left join {{ ref('partner') }}                pn on pn.partner_code    = d.customer_code
left join {{ ref('sales_store_salesperson') }}    vd on vd.salesperson_code    = d.salesperson_code
left join {{ ref('branch_obpl') }}             f  on f.branch_id           = d.branch_id
left join {{ ref('store') }}                    ld on ld.store_code        = lr.resolved_store_code
left join {{ ref('sales_freight_document') }}  fr on fr.document_type     = 'return'
                                                 and fr.doc_entry          = d.doc_entry
