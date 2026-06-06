{{ config(post_hook=clustered_unique_index(['doc_entry', 'line_number'])) }}
-- sales order lines (RDR1) enriched with item hierarchy
-- granularity: one line per (doc_entry, line_number)
-- consumed by sales_fiscal_lines via UNION ALL
-- raw RDR1 does not carry price_before_discount, discount_percentage, total_taxes,
-- inventory_cost_price, U_BDI_PRICE/CUSTO/MARGEM; usage_id/cfop do not apply (an order
-- is not a fiscal document).
-- contributes open_quantity, source_line_number and doc_entry_sales_invoice — NULL in the other types
select
    'order'                                           as document_type,
    l.doc_entry,
    l.line_number,
    l.item_code,
    lower(l.item_description)                         as item_description,
    l.quantity,
    l.open_quantity,
    l.unit_price,
    cast(null as decimal(20, 6))                    as price_before_discount,
    cast(null as decimal(18, 4))                    as discount_percentage,
    l.line_total,
    cast(null as decimal(20, 6))                    as total_taxes,
    cast(null as decimal(20, 6))                    as inventory_cost_price,
    l.line_status,
    cast(null as int)                               as usage_id,
    cast(null as varchar(20))                       as cfop,
    l.warehouse_code,
    l.source_doc_entry,
    l.source_line_number,
    cast(null as int)                               as effective_source_doc_entry,
    l.source_document_type,
    l.doc_entry_sales_invoice,
    cast(null as decimal(18, 2))                    as bdi_price,
    cast(null as decimal(18, 2))                    as cost_price,
    cast(null as decimal(18, 4))                    as margin,
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
from {{ ref('sales_order_lines_rdr1') }}               l
left join {{ ref('item') }}                        h  on  h.item_code  = l.item_code
