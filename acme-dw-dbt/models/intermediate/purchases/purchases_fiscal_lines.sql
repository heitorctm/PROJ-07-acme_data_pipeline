{{ config(post_hook=clustered_unique_index(['document_type', 'doc_entry', 'line_number'])) }}
-- unified purchases lines — pure UNION ALL of the per-type building blocks
-- all type-specific logic (joins with fiscal usage, item) lives in the purchases_<type>_lines models
-- grain: one line per (document_type, doc_entry, line_number)
select * from {{ ref('purchases_invoice_lines') }}
union all
select * from {{ ref('purchases_order_lines') }}
union all
select * from {{ ref('purchases_requisition_lines') }}
