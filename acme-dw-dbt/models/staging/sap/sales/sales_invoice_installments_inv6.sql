select
    DocEntry                          as doc_entry,
    InstlmntID                        as installment_number,
    CAST(DueDate as date)             as due_date,
    CAST(InsTotal as decimal(20, 6))  as installment_amount,
    CAST(Paid as decimal(20, 6))      as paid_amount,
    Status                            as installment_status,
    _ingested_at
from {{ source('raw_sap', 'INV6') }}
