select
    GroupCode   as group_code,
    GroupName   as group_name,
    _ingested_at
from {{ source('raw_sap', 'OCRG') }}
