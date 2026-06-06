select
    CardCode                as partner_code,
    CardName                as partner_name,
    CardFName               as foreign_name,
    CAST(UpdateDate as date) as updated_date,
    UpdateTS                as update_ts,
    GroupCode               as group_code,
    CardType                as partner_type,
    CAST(Balance as decimal(20, 6)) as balance,
    Password                as password,
    LicTradNum              as cpf_cnpj,
    SlpCode                 as salesperson_code,
    U_PARTNER_SHOW_IN_BI  as show_in_bi,
    U_PRESALE              as presale_channel,
    U_franchiseName          as franchise_name,
    CAST(CreateDate as date) as registration_date,
    _ingested_at
from {{ source('raw_sap', 'OCRD') }}
