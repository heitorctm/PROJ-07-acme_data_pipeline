select
    ItemCode                            as item_code,
    PriceList                           as price_list_number,
    CAST(Price as decimal(20, 6))       as price,
    _ingested_at
from {{ source('raw_sap', 'ITM1') }}
