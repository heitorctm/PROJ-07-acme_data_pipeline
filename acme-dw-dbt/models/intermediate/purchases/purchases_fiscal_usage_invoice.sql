{{ config(post_hook=clustered_unique_index(['doc_entry'])) }}
-- main fiscal usage of inbound invoices
-- replicates the sales_fiscal_usage_invoice pattern using PCH12 x OUSG via MainUsage
-- grain: one record per inbound invoice doc_entry
select
    pch12.doc_entry,
    pch12.main_usage       as main_usage_id,
    lower(ousg.usage_description) as main_usage_description
from {{ ref('purchase_invoice_usage_pch12') }}   pch12
left join {{ ref('fiscal_usage_ousg') }}   ousg on ousg.usage_id = pch12.main_usage
