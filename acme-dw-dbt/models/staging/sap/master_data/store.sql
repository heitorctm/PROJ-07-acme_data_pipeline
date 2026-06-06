select
    Code        as store_code,
    Name        as store_name,
    _ingested_at
from {{ source('raw_sap', '@STORES') }}
