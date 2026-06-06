select
    SlpCode     as salesperson_code,
    SlpName     as salesperson_name,
    U_STORE      as store_code,
    _ingested_at
from {{ source('raw_sap', 'OSLP') }}
