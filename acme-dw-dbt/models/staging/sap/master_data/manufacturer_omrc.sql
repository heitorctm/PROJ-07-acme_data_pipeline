select
    FirmCode    as manufacturer_code,
    FirmName    as manufacturer_name,
    _ingested_at
from {{ source('raw_sap', 'OMRC') }}
