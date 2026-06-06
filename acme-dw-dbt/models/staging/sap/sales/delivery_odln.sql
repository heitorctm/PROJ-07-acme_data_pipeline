select
    DocEntry                 as doc_entry,
    DocNum                   as delivery_number,
    CAST(DocDate as date)    as issue_date,
    CAST(CreateDate as date) as creation_date,
    CAST(UpdateDate as date) as updated_date,
    DocStatus                as document_status,
    CANCELED                 as canceled,
    CardCode                 as customer_code,
    CardName                 as customer_name,
    BPLId                    as branch_id,
    _ingested_at
from {{ source('raw_sap', 'ODLN') }}
