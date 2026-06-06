{{ config(post_hook=clustered_unique_index(['doc_entry'])) }}
-- fiscal operation of sales quotes
-- replicates the QUT12 x OUSG join from vw_ranking_vendas_legada via MainUsage
-- granularity: one record per quote doc_entry
select
    qut12.doc_entry,
    qut12.main_usage     as main_usage_id,
    lower(ousg.usage_description) as main_usage_description
from {{ ref('quote_usage_qut12') }}     qut12
left join {{ ref('fiscal_usage_ousg') }} ousg on ousg.usage_id = qut12.main_usage
