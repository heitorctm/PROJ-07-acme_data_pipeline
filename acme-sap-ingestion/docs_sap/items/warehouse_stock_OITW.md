# OITW — Stock per Warehouse

**SAP table:** OITW  
**Bronze name:** warehouse_stock_oitw  
**Total columns in raw:** 7

## Description

Stores the stock balance of each item per warehouse (Items - Warehouse in SAP B1). The composite key is `ItemCode` + `WhsCode`. Complements the `OnHand` field of OITM, which carries only the consolidated balance — here the detail is per warehouse, with additional information on committed stock, ordered stock and average price.

## Relationships

**Parent table — join on `ItemCode`:**
- OITM (`item_master_oitm`) — item registry

**Referenced tables:**
- OWHS via `WhsCode` — warehouse registry

## Column mapping

Source of descriptions: SAP Business One SDK 10.0 — confirmed via `/Inventory_and_Production/OITW.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| ItemCode | Item No. | item_code | nvarchar | rename |
| WhsCode | Warehouse Code | warehouse_code | nvarchar | rename |
| OnHand | In Stock | inventory_quantity | decimal(18,6) | cast |
| IsCommited | Defined | committed_quantity | decimal(18,6) | cast |
| OnOrder | Ordered | ordered_quantity | decimal(18,6) | cast |
| AvgPrice | Average Price | average_price | decimal(18,6) | cast |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 166,104 records: 2,307 items × 72 warehouses
- `committed_quantity` (IsCommited): quantity reserved in open documents (sales orders, production orders)
- `ordered_quantity` (OnOrder): quantity in open purchase orders not yet received
- Real available balance = `inventory_quantity` - `committed_quantity`
