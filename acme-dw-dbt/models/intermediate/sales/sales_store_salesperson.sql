{{ config(post_hook=clustered_unique_index(['salesperson_code'])) }}
-- salesperson enriched with the name of the linked store
-- replicates the OSLP x @STORES join from vw_ranking_vendas_legada via U_STORE
-- granularity: one record per salesperson_code
-- the rule for which store to display on the document (cascade from doc U_Store, customer group, etc.)
-- lives in sales_fiscal_documents (level 2), not here
select
    v.salesperson_code,
    lower(v.salesperson_name)              as salesperson_name,
    v.store_code                       as salesperson_store_code,
    lower(l.store_name)                  as salesperson_store_name
from {{ ref('salesperson_oslp') }}      v
left join {{ ref('store') }} l on l.store_code = v.store_code
