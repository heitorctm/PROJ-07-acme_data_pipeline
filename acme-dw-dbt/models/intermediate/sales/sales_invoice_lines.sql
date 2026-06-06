{{ config(post_hook=clustered_unique_index(['doc_entry', 'line_number'])) }}
-- outbound invoice lines (INV1) enriched with prices, fiscal usage and item hierarchy
-- granularity: one line per (doc_entry, line_number)
-- consumed by sales_fiscal_lines via UNION ALL
select
    'invoice'                                            as document_type,
    l.doc_entry,
    l.line_number,
    l.item_code,
    lower(l.item_description)                         as item_description,
    l.quantity,
    cast(null as decimal(20, 6))                    as open_quantity,
    l.unit_price,
    l.price_before_discount,
    l.discount_percentage,
    l.line_total,
    l.total_taxes,
    l.inventory_cost_price,
    l.line_status,
    l.usage_id,
    lower(l.cfop)                                   as cfop,
    l.warehouse_code,
    l.source_doc_entry,
    cast(null as int)                               as source_line_number,
    cast(null as int)                               as effective_source_doc_entry,
    l.source_document_type,
    cast(null as int)                               as doc_entry_sales_invoice,
    p.bdi_price,
    p.cost_price,
    l.margin,
    op.main_usage_id,
    op.main_usage_description,
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
from {{ ref('sales_invoice_lines_inv1') }}             l
left join {{ ref('sales_prices_invoice') }}            p  on  p.doc_entry    = l.doc_entry
                                                      and p.line_number = l.line_number
left join {{ ref('sales_fiscal_usage_invoice') }}        op on  op.doc_entry   = l.doc_entry
left join {{ ref('item') }}                        h  on  h.item_code  = l.item_code
