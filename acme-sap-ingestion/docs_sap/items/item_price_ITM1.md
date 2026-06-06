# ITM1 — Item Prices per Price List

**SAP table:** ITM1  
**Bronze name:** item_price_itm1  
**Total columns in raw:** 4

## Description

Stores item prices per price list (Item Price List in SAP B1). Each row represents the price of an item in a specific price list. The composite key is `ItemCode` + `PriceList`. The meaning of each price list is in the OPLN table.

## Relationships

**Parent table — join on `ItemCode`:**
- OITM (`item_master_oitm`) — item registry

**Referenced tables:**
- OPLN via `PriceList` — price list registry

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| ItemCode | Item No. | item_code | nvarchar | rename |
| PriceList | Price List No. | price_list_number | smallint | rename |
| Price | List Price | price | decimal(18,6) | cast |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 2,307 items × 100 price lists = 230,700 records total
- All items are present in all 100 lists — complete structure with no gaps
- The name and purpose of each price list is in the OPLN table (`opln_listas_preco`)
