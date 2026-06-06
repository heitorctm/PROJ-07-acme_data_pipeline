{{ config(post_hook=clustered_unique_index(['doc_entry', 'line_number'])) }}
-- purchase requisition lines (PRQ1) enriched with item hierarchy
-- grain: one line per (doc_entry, line_number)
-- consumed by purchases_fiscal_lines via UNION ALL
-- PRQ1 has no price, totals, taxes, ledger_account, usage_id, source_doc_entry
-- (the requisition is the start of the chain, it does not come from another document)
select
    'requisition'                                           as document_type,
    l.doc_entry,
    l.line_number,
    l.item_code,
    l.warehouse_code,
    l.quantity,
    l.open_quantity,
    l.line_status,
    cast(null as decimal(20, 6))                    as unit_price,
    cast(null as decimal(20, 6))                    as price_before_discount,
    cast(null as decimal(18, 4))                    as discount_percentage,
    cast(null as decimal(20, 6))                    as line_total,
    cast(null as decimal(20, 6))                    as total_taxes,
    cast(null as decimal(20, 6))                    as inventory_cost_price,
    cast(null as nvarchar(50))                      as ledger_account,
    cast(null as int)                               as usage_id,
    cast(null as int)                               as source_doc_entry,
    cast(null as int)                               as source_document_type,
    cast(null as int)                               as main_usage_id,
    cast(null as nvarchar(255))                     as main_usage_description,
    h.item_name,
    h.family_code,
    h.family_name,
    h.class_code,
    h.class_name,
    h.sub_class_code,
    h.sub_class_name,
    h.abc_curve,
    h.unit_of_measure,
    h.manufacturer_code,
    l._ingested_at
from {{ ref('purchase_requisition_lines_prq1') }}    l
left join {{ ref('item') }}                        h  on h.item_code  = l.item_code
