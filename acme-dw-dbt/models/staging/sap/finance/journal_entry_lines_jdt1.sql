select
    TransId                             as transaction_id,
    Line_ID                             as line_number,
    Account                             as ledger_account,
    CAST(Credit as decimal(20, 6))      as credit,
    CAST(Debit as decimal(20, 6))       as debit,
    CAST(RefDate as date)               as reference_date,
    ShortName                           as partner_code,
    ContraAct                           as offset_account,
    TransType                           as transaction_type,
    _ingested_at
from {{ source('raw_sap', 'JDT1') }}
