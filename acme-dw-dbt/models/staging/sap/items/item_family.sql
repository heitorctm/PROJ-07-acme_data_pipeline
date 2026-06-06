select
    Code    as family_code,
    Name    as family_name,
    _ingested_at
from {{ source('raw_sap', '@ITEM_FAMILY') }}
