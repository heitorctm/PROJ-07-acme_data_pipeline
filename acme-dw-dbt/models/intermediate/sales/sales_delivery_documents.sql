{{ config(post_hook=clustered_unique_index(['doc_entry'])) }}
-- delivery headers (ODLN)
-- granularity: one record per doc_entry — most recent version
-- deduplicates via ROW_NUMBER as a safeguard; raw uses incremental_upsert (no UpdateTS — only UpdateDate)
-- ODLN has no salesperson_code — deliveries are not assigned to a salesperson in SAP
with deliveries_dedup as (
    select *,
        row_number() over (partition by doc_entry order by _ingested_at desc) as rn
    from {{ ref('delivery_odln') }}
)
select
    e.doc_entry,
    e.delivery_number,
    e.issue_date,
    e.creation_date,
    e.updated_date,
    case e.document_status
        when 'O' then 'open'
        when 'C' then 'closed'
        else lower(e.document_status)
    end                                                  as document_status,
    case e.canceled
        when 'N' then 'no'
        when 'Y' then 'canceled'
        when 'C' then 'reversal'
        else lower(e.canceled)
    end                                                  as canceled,
    e.customer_code,
    lower(pn.partner_name)                              as partner_name,
    pn.group_code,
    lower(pn.group_name)                                 as group_name,
    lower(pn.franchise_name)                              as franchise_name,
    pn.cpf_cnpj_official,
    pn.cpf_cnpj_normalized,
    pn.show_in_bi                                       as partner_show_in_bi,
    e.branch_id,
    lower(f.branch_name)                                 as branch_name,
    lower(f.nomenclature)                                as branch_nomenclature,
    e._ingested_at
from deliveries_dedup                                    e
left join {{ ref('partner') }}             pn on pn.partner_code = e.customer_code
left join {{ ref('branch_obpl') }}          f  on f.branch_id        = e.branch_id
where e.rn = 1
