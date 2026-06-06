select
    ItemCode                                as item_code,
    WhsCode                                 as warehouse_code,
    CAST(OnHand as decimal(20, 6))          as inventory_quantity,
    CAST(IsCommited as decimal(20, 6))      as committed_quantity,
    CAST(OnOrder as decimal(20, 6))         as ordered_quantity,
    CAST(AvgPrice as decimal(20, 6))        as average_price,
    _ingested_at
from {{ source('raw_sap', 'OITW') }}
