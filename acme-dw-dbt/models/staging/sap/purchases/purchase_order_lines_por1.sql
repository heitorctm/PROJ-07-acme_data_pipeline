select
    DocEntry                            as doc_entry,
    LineNum                             as line_number,
    ItemCode                            as item_code,
    WhsCode                             as warehouse_code,
    CAST(Quantity as decimal(20, 6))    as quantity,
    CAST(OpenQty as decimal(20, 6))     as open_quantity,
    LineStatus                          as line_status,
    CAST(Price as decimal(20, 6))       as unit_price,
    CAST(LineTotal as decimal(20, 6))   as line_total,
    BaseEntry                           as source_doc_entry,
    CAST(BaseType as int)               as source_document_type,
    _ingested_at
from {{ source('raw_sap', 'POR1') }}
