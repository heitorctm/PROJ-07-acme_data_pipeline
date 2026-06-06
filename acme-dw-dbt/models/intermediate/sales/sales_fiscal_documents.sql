{{ config(post_hook=clustered_unique_index(['document_type', 'doc_entry'])) }}
-- unified sales document headers — pure UNION ALL of the per-type building blocks
-- all type-specific logic (dedup, CASEs, joins) lives in the sales_<type>_documents models
-- granularity: one record per (document_type, doc_entry)
select * from {{ ref('sales_invoice_documents') }}
union all
select * from {{ ref('sales_quote_documents') }}
union all
select * from {{ ref('sales_return_documents') }}
union all
select * from {{ ref('sales_order_documents') }}
