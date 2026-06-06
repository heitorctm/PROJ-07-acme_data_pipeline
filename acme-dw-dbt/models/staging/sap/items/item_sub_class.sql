select
    Code    as sub_class_code,
    Name    as sub_class_name,
    _ingested_at
from {{ source('raw_sap', '@ITEM_SUB_CLASS') }}
