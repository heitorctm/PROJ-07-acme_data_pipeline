select
    DocEntry                                as doc_entry,
    LineNum                                 as line_number,
    ItemCode                                as item_code,
    WhsCode                                 as warehouse_code,
    AcctCode                                as ledger_account,
    Usage                                   as usage_id,
    CAST(Quantity as decimal(20, 6))        as quantity,
    CAST(Price as decimal(20, 6))           as unit_price,
    CAST(PriceBefDi as decimal(20, 6))      as price_before_discount,
    CAST(DiscPrcnt as decimal(18, 4))       as discount_percentage,
    CAST(LineTotal as decimal(20, 6))       as line_total,
    CAST(VatSum as decimal(20, 6))          as total_taxes,
    CAST(INMPrice as decimal(20, 6))        as inventory_cost_price,
    BaseEntry                               as source_doc_entry,
    CAST(BaseType as int)                   as source_document_type,
    _ingested_at
from {{ source('raw_sap', 'PCH1') }}
