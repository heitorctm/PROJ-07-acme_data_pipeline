select
    DocEntry                          as doc_entry,
    LineNum                           as line_number,
    ExpnsCode                         as expense_code,
    CAST(LineTotal as decimal(20, 6)) as expense_amount,
    _ingested_at
from {{ source('raw_sap', 'INV3') }}
