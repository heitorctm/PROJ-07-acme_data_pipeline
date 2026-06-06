select
    DocEntry                           as doc_entry,
    LineNum                            as line_number,
    ItemCode                           as item_code,
    WhsCode                            as warehouse_code,
    CAST(Quantity as decimal(20, 6))   as quantity,
    LineStatus                         as line_status,
    BaseEntry                          as source_doc_entry,
    BaseLine                           as source_line_number,
    CAST(BaseType as int)              as source_document_type,
    _ingested_at
from {{ source('raw_sap', 'DLN1') }}
