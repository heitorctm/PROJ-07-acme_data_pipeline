# PRQ1 — Purchase Requisition Lines

**SAP table:** PRQ1  
**Bronze name:** purchase_requisition_lines_prq1  
**Total raw columns:** 8

## Description

Stores the item rows of purchase requisitions (Purchase Request Rows in SAP B1). Each row represents a product or service requested internally. It has `OpenQty` for tracking the quantity not yet fulfilled by the corresponding purchase order.

## Relationships

**Parent table — join on `DocEntry`:**
- OPRQ (`purchase_requisition_oprq`) — purchase requisition header

**Tables referenced per row:**
- OITM via `ItemCode` — master record of the requested item
- OWHS via `WhsCode` — destination warehouse

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Internal Document ID | doc_entry | int | rename |
| LineNum | Row Number | line_number | int | rename |
| ItemCode | Item No. | item_code | nvarchar | rename |
| WhsCode | Warehouse Code | warehouse_code | nvarchar | rename |
| Quantity | Quantity | quantity | decimal(18,6) | cast |
| OpenQty | Remaining Open Quantity | open_quantity | decimal(18,6) | cast |
| LineStatus | Row Status | line_status | nvarchar | CASE (see enums) |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### LineStatus — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| O | Open | 2,655 |
| C | Closed | 6,007 |

## Database notes

- 8,662 rows for 1,278 distinct requisitions — average of 6–7 items per requisition
- `OpenQty` useful for identifying requisitions partially fulfilled by the purchase order
