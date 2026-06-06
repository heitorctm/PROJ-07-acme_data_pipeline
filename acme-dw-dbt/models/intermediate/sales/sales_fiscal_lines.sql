{{ config(post_hook=clustered_unique_index(['document_type', 'doc_entry', 'line_number'])) }}
-- unified sales lines — pure UNION ALL of the per-type building blocks
-- all type-specific logic (joins with prices, fiscal usage, item) lives in the sales_<type>_lines models
-- granularity: one line per (document_type, doc_entry, line_number)
select * from {{ ref('sales_invoice_lines') }}
union all
select * from {{ ref('sales_quote_lines') }}
union all
select * from {{ ref('sales_return_lines') }}
union all
select * from {{ ref('sales_order_lines') }}
