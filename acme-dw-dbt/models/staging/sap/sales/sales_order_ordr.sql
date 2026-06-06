select
    DocEntry                             as doc_entry,
    DocNum                               as order_number,
    CAST(DocDate as date)                as issue_date,
    CAST(DocDueDate as date)             as expected_delivery_date,
    CAST(CreateDate as date)             as creation_date,
    CAST(UpdateDate as date)             as updated_date,
    UpdateTS                             as update_ts,
    DocStatus                            as document_status,
    CANCELED                             as canceled,
    CardCode                             as customer_code,
    CardName                             as customer_name,
    SlpCode                              as salesperson_code,
    BPLId                                as branch_id,
    CAST(DocTotal as decimal(20, 6))     as document_total,
    CAST(GrosProfit as decimal(20, 6))   as gross_profit,
    CAST(VatSum as decimal(20, 6))       as total_taxes,
    _ingested_at
from {{ source('raw_sap', 'ORDR') }}
