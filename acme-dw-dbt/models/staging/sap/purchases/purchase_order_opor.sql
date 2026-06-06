select
    DocEntry                            as doc_entry,
    DocNum                              as order_number,
    CAST(DocDate as date)               as issue_date,
    CAST(CreateDate as date)            as creation_date,
    CAST(UpdateDate as date)            as updated_date,
    DocStatus                           as document_status,
    CANCELED                            as canceled,
    CardCode                            as supplier_code,
    CardName                            as supplier_name,
    CAST(DocTotal as decimal(20, 6))    as document_total,
    BPLId                               as branch_id,
    UserSign                            as user_id,
    _ingested_at
from {{ source('raw_sap', 'OPOR') }}
