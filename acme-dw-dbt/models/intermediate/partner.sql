{{ config(post_hook=clustered_unique_index(['partner_code']), tags=['common']) }}
-- business partner enriched with the group name and a normalized cnpj/cpf
-- replicates the joins between OCRD and OCRG in vw_ranking_vendas_legada
-- and the cnpj/cpf extraction logic that comes from the password field (Password)
-- granularity: one record per partner_code
-- partner_name comes from OCRD.CardName (the primary field, always populated)
-- foreign_name (OCRD.CardFName) is NOT exposed here — it stays in staging for future cases
select
    p.partner_code,
    lower(p.partner_name)                                  as partner_name,
    case p.partner_type
        when 'C' then 'customer'
        when 'S' then 'supplier'
        when 'L' then 'lead'
        else lower(p.partner_type)
    end                                                     as partner_type,
    p.group_code,
    lower(g.group_name)                                     as group_name,
    p.salesperson_code,
    lower(p.franchise_name)                                  as franchise_name,
    case p.presale_channel
        when 'N'  then 'no'
        when 'P'  then 'crm'
        when 'PS' then 'crm steel frame'
        when 'PD' then 'crm drywall'
        when 'PP' then 'crm floors'
        when 'PA' then 'crm acoustic'
        when 'PE' then 'crm frames'
        when 'PQ' then 'crm mortar'
        when 'I'  then 'internal (google)'
        else lower(p.presale_channel)
    end                                                     as presale_channel,
    case p.show_in_bi
        when 'S' then 'yes'
        when 'N' then 'no'
        else lower(p.show_in_bi)
    end                                                     as show_in_bi,
    p.cpf_cnpj                                              as cpf_cnpj_official,
    coalesce(
        nullif(
            replace(replace(replace(p.password, '.', ''), '/', ''), '-', ''),
            ''
        ),
        concat('SAP', p.partner_code)
    )                                                       as cpf_cnpj_normalized,
    p.registration_date,
    p.updated_date
from {{ ref('business_partner_ocrd') }}      p
left join {{ ref('partner_group_ocrg') }} g on g.group_code = p.group_code
