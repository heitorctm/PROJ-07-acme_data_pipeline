-- SCD Type 2 invariant: each (salesperson_code, store_code) can have at
-- most 1 open period (valid_to IS NULL = current store from the master record). When
-- moving stores, the previous period is closed and a new one opened. More than one open
-- period for the same combination indicates a bug in closing valid_to.

select
    salesperson_code,
    store_code,
    count(*) as versoes_vigentes
from {{ ref('salesperson_bridge') }}
where valid_to is null
group by salesperson_code, store_code
having count(*) > 1
