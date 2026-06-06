select
    INTERNAL_K      as user_id,
    USER_CODE       as user_login,
    U_NAME          as user_name,
    Department      as department_id,
    _ingested_at
from {{ source('raw_sap', 'OUSR') }}
