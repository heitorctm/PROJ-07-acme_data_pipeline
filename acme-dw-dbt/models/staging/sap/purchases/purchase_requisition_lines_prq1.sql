select
    DocEntry                            as doc_entry,
    LineNum                             as line_number,
    ItemCode                            as item_code,
    WhsCode                             as warehouse_code,
    CAST(Quantity as decimal(20, 6))    as quantity,
    CAST(OpenQty as decimal(20, 6))     as open_quantity,
    LineStatus                          as line_status,
    _ingested_at
from {{ source('raw_sap', 'PRQ1') }}
