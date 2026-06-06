{{ config(post_hook=clustered_unique_index(['user_id'])) }}
-- SAP user
-- granularity: one record per user_id
-- cross-domain brick: used by purchases (UserSign in OPOR/OPRQ)
select
    user_id,
    user_login,
    lower(user_name)     as user_name,
    department_id
from {{ ref('user_ousr') }}
