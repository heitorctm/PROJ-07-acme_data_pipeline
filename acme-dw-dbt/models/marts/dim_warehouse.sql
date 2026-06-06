{{ config(post_hook=clustered_unique_index(['warehouse_code']), tags=['dimension']) }}
-- dim_warehouse — warehouse dimension for Power BI.
-- granularity: 1 record per warehouse_code (WhsCode from SAP).
--
-- a warehouse is where goods physically sit. A store can have several
-- (megastore + factory + direct shipping + drop-shipping + marketplace).
-- 72 warehouses in SAP today (jan/2026), all active.
--
-- coverage:
--   ~43% (31 warehouses) have a linked store — the "commercial" ones (store, megastore).
--   ~57% (41 warehouses) are operational (factory, drop-shipping, Mercado Livre,
--   direct shipping, accounting) and have no linked store.
--
-- store_name replicates the dim_store rule: fall back to the old name if there is no new one.
select
    warehouse.warehouse_code,
    warehouse.warehouse_name,

    -- branch
    warehouse.branch_id,
    warehouse.branch_name,
    warehouse.branch_nomenclature,

    -- linked store (may be NULL for operational warehouses)
    warehouse.store_code,
    coalesce(lp.new_store_name, lp.old_store_name)            as store_name

from {{ ref('warehouse') }} warehouse
left join {{ ref('standardized_store') }} lp on lp.store_code = warehouse.store_code
