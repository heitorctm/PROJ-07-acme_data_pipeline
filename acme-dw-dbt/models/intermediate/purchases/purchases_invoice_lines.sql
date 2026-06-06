{{ config(post_hook=clustered_unique_index(['doc_entry', 'line_number'])) }}
-- inbound invoice lines (PCH1) enriched with fiscal usage and item hierarchy
-- grain: one line per (doc_entry, line_number)
-- consumed by purchases_fiscal_lines via UNION ALL
select
    'invoice'                                            as document_type,
    l.doc_entry,
    l.line_number,
    l.item_code,
    l.warehouse_code,
    l.quantity,
    cast(null as decimal(20, 6))                    as open_quantity,
    cast(null as nvarchar(1))                       as line_status,
    l.unit_price,
    l.price_before_discount,
    l.discount_percentage,
    l.line_total,
    l.total_taxes,
    l.inventory_cost_price,
    l.ledger_account,
    l.usage_id,
    l.source_doc_entry,
    l.source_document_type,
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
from {{ ref('purchase_invoice_lines_pch1') }}           l
left join {{ ref('purchases_fiscal_usage_invoice') }}       op on op.doc_entry   = l.doc_entry
left join {{ ref('item') }}                        h  on h.item_code  = l.item_code
