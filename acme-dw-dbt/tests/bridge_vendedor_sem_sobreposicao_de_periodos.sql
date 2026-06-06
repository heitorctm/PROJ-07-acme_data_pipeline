-- Invariant: for the same (salesperson_code, store_code), two periods cannot
-- overlap in time. Each code is in ONE store at a time (the store from the
-- master record); when it moves stores, the old period closes (valid_to = yesterday)
-- and the new one opens. Overlapping periods in the same store indicate a bug in
-- closing valid_to during forward-tracking.

select
    a.salesperson_code,
    a.store_code,
    a.valid_from      as valid_from_a,
    a.valid_to        as valid_to_a,
    b.valid_from      as valid_from_b,
    b.valid_to        as valid_to_b
from {{ ref('salesperson_bridge') }} a
join {{ ref('salesperson_bridge') }} b
  on  a.salesperson_code = b.salesperson_code
 and  a.store_code     = b.store_code
 and  a.valid_from     <> b.valid_from
where a.valid_from <= coalesce(b.valid_to, '9999-12-31')
  and b.valid_from <= coalesce(a.valid_to, '9999-12-31')
  and a.valid_from <  b.valid_from
