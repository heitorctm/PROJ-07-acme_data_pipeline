{{ config(post_hook=clustered_unique_index(['item_code', 'warehouse_code'])) }}
-- current inventory by item × warehouse.
-- grain: 1 line per (item_code, warehouse_code).
--
-- snapshot of OITW (Items Per Warehouse) enriched with the item hierarchy
-- (family, class, sub-class, ABC, unit) and the warehouse (branch, store).
--
-- project rule: intermediate models DO NOT FILTER. inactive warehouses are preserved here — the
-- `warehouse_inactive` column lets the fact decide the filter appropriate for each use case.
--
-- cross-domain building block. currently consumed by mart_inventory.fact_inventory (current snapshot).

select
    -- keys
    o.item_code,
    o.warehouse_code,

    -- OITW metrics
    o.inventory_quantity,
    o.committed_quantity,
    o.ordered_quantity,
    o.average_price                                                   as average_cost_price,

    -- item attributes
    i.item_name,
    i.family_code,
    i.family_name,
    i.class_code,
    i.class_name,
    i.sub_class_code,
    i.sub_class_name,
    i.abc_curve,
    i.unit_of_measure,

    -- warehouse attributes (incl. status — the fact decides whether to filter)
    d.warehouse_name,
    d.branch_id,
    d.branch_name,
    d.store_code,
    d.store_name,
    d.inactive                                                       as warehouse_inactive
from {{ ref('warehouse_stock_oitw') }}      o
inner join {{ ref('item') }}                 i on i.item_code     = o.item_code
inner join {{ ref('warehouse') }}             d on d.warehouse_code = o.warehouse_code
