select
    [Ordem Vendedor]                                            as salesperson_order,
    cast([Data] as date)                                        as date,
    [Ordem Filial]                                              as branch_order,
    [Loja]                                                      as store,
    [Vendedor]                                                  as salesperson,
    cast([Meta Diária] as decimal(20, 6))                       as daily_goal,
    _ingested_at
from {{ source('raw_sharepoint', 'retail_goals') }}
