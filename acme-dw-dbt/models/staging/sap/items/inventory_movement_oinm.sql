select
    TransNum                                            as transaction_number,
    CAST(DocDate as date)                               as movement_date,
    ItemCode                                            as item_code,
    Warehouse                                           as warehouse_code,
    CAST(InQty as decimal(20, 6))                       as inflow_quantity,
    CAST(OutQty as decimal(20, 6))                      as outflow_quantity,
    CAST(TransValue as decimal(20, 6))                  as transaction_amount,
    CAST(CalcPrice as decimal(20, 6))                   as calculated_average_price,
    CAST(Balance as decimal(20, 6))                     as inventory_value_after_movement,
    TransType                                           as transaction_type,
    CreatedBy                                           as source_doc_entry,
    BASE_REF                                            as source_document_number,
    DocLineNum                                          as source_line_number,
    _ingested_at
from {{ source('raw_sap', 'OINM') }}
