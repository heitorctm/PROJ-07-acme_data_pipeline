{{ config(post_hook=clustered_unique_index(['document_type', 'doc_entry'])) }}
-- unified purchases headers — pure UNION ALL of the per-type building blocks
-- all type-specific logic (dedup, CASEs, joins) lives in the purchases_<type>_documents models
-- grain: one record per (document_type, doc_entry)
select * from {{ ref('purchases_invoice_documents') }}
union all
select * from {{ ref('purchases_order_documents') }}
union all
select * from {{ ref('purchases_requisition_documents') }}
