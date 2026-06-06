select
    WhsCode     as warehouse_code,
    WhsName     as warehouse_name,
    BPLid       as branch_id,
    U_STORE      as store_code,
    Inactive    as inactive,
    _ingested_at
from {{ source('raw_sap', 'OWHS') }}
