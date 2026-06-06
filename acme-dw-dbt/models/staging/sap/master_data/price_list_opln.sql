select
    ListNum     as price_list_number,
    ListName    as price_list_name,
    _ingested_at
from {{ source('raw_sap', 'OPLN') }}
