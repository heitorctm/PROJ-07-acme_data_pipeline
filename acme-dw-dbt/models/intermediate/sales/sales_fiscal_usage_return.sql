{{ config(post_hook=clustered_unique_index(['doc_entry'])) }}
-- fiscal operation of sales returns
-- replicates the RIN12 x OUSG join from vw_ranking_vendas_legada via MainUsage
-- granularity: one record per return doc_entry
select
    rin12.doc_entry,
    rin12.main_usage     as main_usage_id,
    lower(ousg.usage_description) as main_usage_description
from {{ ref('sales_return_usage_rin12') }}     rin12
left join {{ ref('fiscal_usage_ousg') }} ousg on ousg.usage_id = rin12.main_usage
