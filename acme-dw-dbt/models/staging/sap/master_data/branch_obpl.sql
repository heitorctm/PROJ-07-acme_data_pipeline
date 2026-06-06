select
    BPLId           as branch_id,
    BPLName         as branch_name,
    U_NOMENCLATURE  as nomenclature,
    _ingested_at
from {{ source('raw_sap', 'OBPL') }}
