select
    ObjectCode      as object_code,
    DocSubType      as document_subtype,
    SeqCode         as series_code,
    SeqName         as series_name,
    _ingested_at
from {{ source('raw_sap', 'NFN1') }}
