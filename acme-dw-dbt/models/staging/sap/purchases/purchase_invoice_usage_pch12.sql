select
    DocEntry        as doc_entry,
    MainUsage       as main_usage,
    _ingested_at
from {{ source('raw_sap', 'PCH12') }}
