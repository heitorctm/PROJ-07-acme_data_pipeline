{{ config(
    materialized='incremental',
    unique_key=['date', 'item_code', 'warehouse_code'],
    incremental_strategy='append',
    post_hook=clustered_unique_index(['date', 'item_code', 'warehouse_code']),
    tags=['fact']
) }}
-- fact_daily_inventory_movement — history of inventory flow aggregated by day.
-- granularity: 1 row per (date, item_code, warehouse_code).
--
-- materialization: incremental APPEND. Each run only adds closed days that are not
-- yet in the fact. SAP B1 does not alter past movements (OINM = audit trail) → a closed
-- day is immutable → a pure append is safe and cheaper than a merge.
--
-- watermark: `movement_date < cast(getdate() as date)`.
--   - the CURRENT day never enters here (still volatile — hours remaining).
--   - the "today" position is the responsibility of [[fact_inventory]] (OITW snapshot).
--
-- consumes: int_inventory.inventory_movements (OINM enriched with hierarchy).
--
-- ## metrics
--
-- FLOW (day sums):
--   - inflow_quantity, outflow_quantity, movement_quantity
--   - transacted_amount (SUM of TransValue — how much came in/out in R$)
--   - movement_count (how many transactions that day)
--
-- END-OF-DAY STATE (from the last movement — highest transaction_number of the day):
--   - calculated_average_price (CalcPrice — the item's average cost after the last movement)
--   - inventory_value_after_movement (Balance — R$ value accumulated by SAP)
--   - quantity_after_movement (balance in units at end of day)
--
-- ## reconstructing the balance on a past date
--
--   select top 1 inventory_value_after_movement, quantity_after_movement
--   from mart_inventory.fact_daily_inventory_movement
--   where item_code = 'X' and warehouse_code = 'Y' and date <= 'D'
--   order by date desc;
--
-- no cumulative sum needed — Balance is already natively cumulative in SAP.

with
    movements as (
        select *
        from {{ ref('inventory_movements') }}
        where movement_date < cast(getdate() as date)
        {% if is_incremental() %}
          and movement_date > (select coalesce(max(date), cast('1900-01-01' as date)) from {{ this }})
        {% endif %}
    ),

    daily_flow as (
        select
            item_code,
            warehouse_code,
            movement_date                                              as date,
            sum(inflow_quantity)                                     as inflow_quantity,
            sum(outflow_quantity)                                       as outflow_quantity,
            sum(movement_quantity)                                   as movement_quantity,
            sum(transaction_amount)                                        as transacted_amount,
            count(*)                                                    as movement_count
        from movements
        group by item_code, warehouse_code, movement_date
    ),

    end_of_day_state as (
        -- last movement of each (item, warehouse, day) = end-of-day balance + attributes.
        select *
        from (
            select
                item_code,
                warehouse_code,
                movement_date                                          as date,
                calculated_average_price,
                inventory_value_after_movement,
                quantity_after_movement,
                -- item hierarchy (already enriched in the int)
                item_name,
                family_code,
                family_name,
                class_code,
                class_name,
                sub_class_code,
                sub_class_name,
                abc_curve,
                unit_of_measure,
                -- warehouse hierarchy
                warehouse_name,
                branch_id,
                branch_name,
                store_code,
                store_name,
                row_number() over (
                    partition by item_code, warehouse_code, movement_date
                    order by transaction_number desc
                ) as rn
            from movements
        ) ranked
        where rn = 1
    )

select
    -- keys
    e.date,
    e.item_code,
    e.warehouse_code,

    -- item attributes
    e.item_name,
    e.family_code,
    e.family_name,
    e.class_code,
    e.class_name,
    e.sub_class_code,
    e.sub_class_name,
    e.abc_curve,
    e.unit_of_measure,

    -- warehouse attributes
    e.warehouse_name,
    e.branch_id,
    e.branch_name,
    e.store_code,
    e.store_name,

    -- flow metrics (day sum)
    f.inflow_quantity,
    f.outflow_quantity,
    f.movement_quantity,
    f.transacted_amount,
    f.movement_count,

    -- state metrics (end of day)
    e.calculated_average_price,
    e.inventory_value_after_movement,
    e.quantity_after_movement
from end_of_day_state                        e
inner join daily_flow                        f
    on  f.date            = e.date
    and f.item_code     = e.item_code
    and f.warehouse_code = e.warehouse_code
