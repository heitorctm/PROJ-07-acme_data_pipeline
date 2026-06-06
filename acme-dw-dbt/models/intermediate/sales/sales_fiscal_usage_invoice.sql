{{ config(post_hook=clustered_unique_index(['doc_entry'])) }}
-- fiscal operation of outbound invoices
-- replicates the INV12 x OUSG join from vw_ranking_vendas_legada via MainUsage
-- granularity: one record per invoice doc_entry
select
    inv12.doc_entry,
    inv12.main_usage     as main_usage_id,
    lower(ousg.usage_description) as main_usage_description
from {{ ref('sales_invoice_usage_inv12') }}     inv12
left join {{ ref('fiscal_usage_ousg') }} ousg on ousg.usage_id = inv12.main_usage
