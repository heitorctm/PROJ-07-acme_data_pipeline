select
    ID          as usage_id,
    Usage       as usage_description,
    _ingested_at
from {{ source('raw_sap', 'OUSG') }}
