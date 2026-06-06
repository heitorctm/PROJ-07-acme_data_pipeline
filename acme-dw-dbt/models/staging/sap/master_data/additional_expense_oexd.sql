select
    ExpnsCode   as expense_code,
    ExpnsName   as expense_name,
    _ingested_at
from {{ source('raw_sap', 'OEXD') }}
