{{ config(post_hook=clustered_unique_index(['item_code', 'warehouse_code']), tags=['fact']) }}
-- fact_inventory — CURRENT inventory snapshot per item × warehouse, valued at list
-- price, with turnover/coverage metrics derived from the history of outflows.
-- granularity: 1 row per (item_code, warehouse_code).
--
-- consumes:
--   - int_inventory.current_inventory    (qty + denormalized hierarchies)
--   - int_common.item_price_list         (price per (item, list) — filtered by the var)
--   - int_inventory.inventory_movements  (historical outflows for turnover/coverage)
--
-- ## filters (mart decides; the ints preserve)
--   - inactive warehouses excluded.
--   - items with no price registered in the current list → list_price NULL.
--   - items with no historical outflow → outflow_quantity_* = 0, turnover/coverage NULL.
--
-- ## turnover windows
--   - 30d, 45d, 60d → last N calendar days counted from yesterday (D-1).
--   - "year" → year-to-date: from Jan 1 of the current year to yesterday (D-1).
--
-- ## formulas
--   turnover_Xd     = outflow_quantity_Xd / inventory_quantity
--                     → how many times the current inventory "turned over" in the period.
--   coverage_days_Xd = inventory_quantity × N_window_days / outflow_quantity_Xd
--                     → in how many days the inventory runs out at the window's pace.
--   coverage_ytd uses (days elapsed in the year up to yesterday) as N.

with
    outflows_per_window as (
        select
            item_code,
            warehouse_code,
            sum(case when movement_date >= dateadd(day, -30, cast(getdate() as date))
                     then outflow_quantity else 0 end)                  as outflow_quantity_30d,
            sum(case when movement_date >= dateadd(day, -45, cast(getdate() as date))
                     then outflow_quantity else 0 end)                  as outflow_quantity_45d,
            sum(case when movement_date >= dateadd(day, -60, cast(getdate() as date))
                     then outflow_quantity else 0 end)                  as outflow_quantity_60d,
            sum(case when movement_date >= datefromparts(year(getdate()), 1, 1)
                     then outflow_quantity else 0 end)                  as outflow_quantity_ytd,
            max(case when outflow_quantity > 0 then movement_date end) as last_outflow_date
        from {{ ref('inventory_movements') }}
        where movement_date < cast(getdate() as date)
        group by item_code, warehouse_code
    )

select
    -- keys
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

    -- current snapshot
    e.inventory_quantity,
    e.committed_quantity,
    e.ordered_quantity,
    p.list_price,
    e.inventory_quantity * p.list_price                                as inventory_value_at_list_price,

    -- historical outflows (qty in units)
    coalesce(s.outflow_quantity_30d, 0)                                 as outflow_quantity_30d,
    coalesce(s.outflow_quantity_45d, 0)                                 as outflow_quantity_45d,
    coalesce(s.outflow_quantity_60d, 0)                                 as outflow_quantity_60d,
    coalesce(s.outflow_quantity_ytd, 0)                                 as outflow_quantity_ytd,

    -- turnover (times the current inventory turned over in the period)
    case when e.inventory_quantity > 0
         then coalesce(s.outflow_quantity_30d, 0) / e.inventory_quantity
         end                                                            as turnover_30d,
    case when e.inventory_quantity > 0
         then coalesce(s.outflow_quantity_45d, 0) / e.inventory_quantity
         end                                                            as turnover_45d,
    case when e.inventory_quantity > 0
         then coalesce(s.outflow_quantity_60d, 0) / e.inventory_quantity
         end                                                            as turnover_60d,
    case when e.inventory_quantity > 0
         then coalesce(s.outflow_quantity_ytd, 0) / e.inventory_quantity
         end                                                            as turnover_ytd,

    -- coverage in days (how long the inventory lasts at the window's pace)
    case when s.outflow_quantity_30d > 0
         then e.inventory_quantity * 30.0 / s.outflow_quantity_30d
         end                                                            as coverage_days_30d,
    case when s.outflow_quantity_45d > 0
         then e.inventory_quantity * 45.0 / s.outflow_quantity_45d
         end                                                            as coverage_days_45d,
    case when s.outflow_quantity_60d > 0
         then e.inventory_quantity * 60.0 / s.outflow_quantity_60d
         end                                                            as coverage_days_60d,
    case when s.outflow_quantity_ytd > 0
         then e.inventory_quantity
              * (datediff(day, datefromparts(year(getdate()), 1, 1), cast(getdate() as date)) + 1.0)
              / s.outflow_quantity_ytd
         end                                                            as coverage_days_ytd,

    -- activity
    s.last_outflow_date,
    case when s.last_outflow_date is not null
         then datediff(day, s.last_outflow_date, cast(getdate() as date))
         end                                                            as days_without_outflow
from {{ ref('current_inventory') }}              e
left join {{ ref('item_price_list') }}      p
    on  p.item_code        = e.item_code
    and p.price_list_number = {{ var('current_price_list') }}
left join outflows_per_window                s
    on  s.item_code     = e.item_code
    and s.warehouse_code = e.warehouse_code
where e.warehouse_inactive <> 'yes'
