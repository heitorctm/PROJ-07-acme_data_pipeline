select
    DocEntry                            as doc_entry,
    DocNum                              as requisition_number,
    CAST(DocDate as date)               as issue_date,
    CAST(CreateDate as date)            as creation_date,
    CAST(UpdateDate as date)            as updated_date,
    DocStatus                           as document_status,
    CANCELED                            as canceled,
    UserSign                            as user_id,
    BPLId                               as branch_id,
    U_externalTicket                      as external_ticket,
    CAST(U_externalTicketDate as date)    as external_ticket_date,
    _ingested_at
from {{ source('raw_sap', 'OPRQ') }}
