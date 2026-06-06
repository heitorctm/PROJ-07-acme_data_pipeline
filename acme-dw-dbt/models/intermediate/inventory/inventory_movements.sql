{{ config(post_hook=clustered_unique_index(['transaction_number'])) }}
-- inventory movements (OINM) enriched with item, warehouse, sign and type description.
-- grain: one line per transaction_number (PK of the SAP B1 audit trail).
-- single source to reconstruct inventory balance + value at any past date.
--
-- TransTypes mapped per the SAP B1 documentation; generic fallback to capture
-- new types that may appear without having to break the model.
select
    m.transaction_number,
    m.movement_date,
    m.item_code,
    m.warehouse_code,
    m.inflow_quantity,
    m.outflow_quantity,
    m.inflow_quantity - m.outflow_quantity                       as movement_quantity,
    m.transaction_amount,
    m.calculated_average_price,
    m.inventory_value_after_movement,
    case
        when m.calculated_average_price > 0
            then m.inventory_value_after_movement / m.calculated_average_price
        else null
    end                                                             as quantity_after_movement,

    -- sign/direction of the movement
    case
        when m.inflow_quantity > 0 and m.outflow_quantity = 0    then 'inflow'
        when m.outflow_quantity   > 0 and m.inflow_quantity = 0  then 'outflow'
        when m.inflow_quantity = 0 and m.outflow_quantity = 0    then 'value_adjustment'
        else 'mixed'
    end                                                             as movement_direction,

    -- transaction type (SAP B1) — slug
    m.transaction_type,
    case m.transaction_type
        when 13         then 'sales_invoice'
        when 14         then 'customer_return'
        when 15         then 'delivery'
        when 16         then 'delivery_return'
        when 18         then 'purchase_invoice'
        when 19         then 'supplier_return'
        when 20         then 'goods_receipt'
        when 21         then 'receipt_return'
        when 58         then 'inventory_update'
        when 59         then 'manual_inflow'
        when 60         then 'manual_outflow'
        when 67         then 'transfer'
        when 68         then 'production_order'
        when 69         then 'import_costs'
        when 132        then 'correction_invoice'
        when 162        then 'revaluation'
        when 10000071   then 'inventory_count'
        when 310000001  then 'initial_balance'
        else 'type_' + cast(m.transaction_type as varchar(20))
    end                                                             as transaction_type_description,

    -- source document
    m.source_doc_entry,
    m.source_document_number,
    m.source_line_number,

    -- item hierarchy (from int_common.item)
    i.item_name,
    i.family_code,
    i.family_name,
    i.class_code,
    i.class_name,
    i.sub_class_code,
    i.sub_class_name,
    i.abc_curve,
    i.unit_of_measure,
    i.is_stockable,

    -- warehouse (from int_common.warehouse)
    d.warehouse_name,
    d.branch_id,
    d.branch_name,
    d.store_code,
    d.store_name,

    m._ingested_at
from {{ ref('inventory_movement_oinm') }} m
left join {{ ref('item') }}     i on i.item_code     = m.item_code
left join {{ ref('warehouse') }} d on d.warehouse_code = m.warehouse_code
