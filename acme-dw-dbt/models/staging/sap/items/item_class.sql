select
    Code    as class_code,
    Name    as class_name,
    _ingested_at
from {{ source('raw_sap', '@ITEM_CLASS') }}
