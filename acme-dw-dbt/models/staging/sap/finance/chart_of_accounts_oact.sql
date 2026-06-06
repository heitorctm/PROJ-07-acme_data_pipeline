select
    AcctCode    as account_code,
    AcctName    as account_name,
    _ingested_at
from {{ source('raw_sap', 'OACT') }}
