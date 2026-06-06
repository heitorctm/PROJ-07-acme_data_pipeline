select
    TransId         as transaction_id,
    CAST(RefDate as date) as reference_date,
    TransType       as transaction_type,
    Memo            as historical,
    BaseRef         as document_reference,
    _ingested_at
from {{ source('raw_sap', 'OJDT') }}
