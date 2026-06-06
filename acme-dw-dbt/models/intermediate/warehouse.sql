{{ config(post_hook=clustered_unique_index(['warehouse_code']), tags=['common']) }}
-- warehouse enriched with branch and store
-- granularity: one record per warehouse_code
-- cross-domain brick: used by sales, purchases and inventory
select
    d.warehouse_code,
    lower(d.warehouse_name)              as warehouse_name,
    d.branch_id,
    lower(f.branch_name)                as branch_name,
    lower(f.nomenclature)               as branch_nomenclature,
    d.store_code,
    lower(l.store_name)                  as store_name,
    case d.inactive
        when 'Y' then 'yes'
        when 'N' then 'no'
        else lower(d.inactive)
    end                                 as inactive
from {{ ref('warehouse_owhs') }}         d
left join {{ ref('branch_obpl') }}      f on f.branch_id   = d.branch_id
left join {{ ref('store') }}             l on l.store_code = d.store_code
