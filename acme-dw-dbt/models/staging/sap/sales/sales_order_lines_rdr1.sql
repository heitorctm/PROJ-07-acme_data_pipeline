select
    DocEntry                           as doc_entry,
    LineNum                            as line_number,
    ItemCode                           as item_code,
    Dscription                         as item_description,
    CAST(Quantity as decimal(20, 6))   as quantity,
    CAST(Price as decimal(20, 6))      as unit_price,
    CAST(LineTotal as decimal(20, 6))  as line_total,
    WhsCode                            as warehouse_code,
    LineStatus                         as line_status,
    CAST(OpenQty as decimal(20, 6))    as open_quantity,
    BaseEntry                          as source_doc_entry,
    BaseLine                           as source_line_number,
    CAST(BaseType as int)              as source_document_type,
    TrgetEntry                         as doc_entry_sales_invoice,
    _ingested_at
from {{ source('raw_sap', 'RDR1') }}
