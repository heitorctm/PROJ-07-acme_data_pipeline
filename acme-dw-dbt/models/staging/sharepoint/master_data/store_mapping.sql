select
    ANTIGO                                                      as old_store_name,
    NOVO                                                        as new_store_name,
    right('00000000' + {{ digits_only('CEP') }}, 8)          as postal_code,
    _ingested_at
from {{ source('raw_sharepoint', 'store_mapping') }}
