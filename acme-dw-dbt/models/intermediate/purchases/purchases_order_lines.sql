{{ config(post_hook=clustered_unique_index(['doc_entry', 'line_number'])) }}
-- purchase order lines (POR1) enriched with item hierarchy
-- grain: one line per (doc_entry, line_number)
-- consumed by purchases_fiscal_lines via UNION ALL
-- POR1 has no price_before_discount/discount_percentage/total_taxes/inventory_cost_price/
-- ledger_account/usage_id (it is not a fiscal document) — all NULL in the canonical schema
select
    'order'                                           as document_type,
    l.doc_entry,
    l.line_number,
    l.item_code,
    l.warehouse_code,
    l.quantity,
    l.open_quantity,
    l.line_status,
    l.unit_price,
    cast(null as decimal(20, 6))                    as price_before_discount,
    cast(null as decimal(18, 4))                    as discount_percentage,
    l.line_total,
    cast(null as decimal(20, 6))                    as total_taxes,
    cast(null as decimal(20, 6))                    as inventory_cost_price,
    cast(null as nvarchar(50))                      as ledger_account,
    cast(null as int)                               as usage_id,
    l.source_doc_entry,
    l.source_document_type,
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
from {{ ref('purchase_order_lines_por1') }}        l
left join {{ ref('item') }}                        h  on h.item_code  = l.item_code
