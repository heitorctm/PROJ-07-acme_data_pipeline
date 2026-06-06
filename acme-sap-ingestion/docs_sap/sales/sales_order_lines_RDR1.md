# RDR1 — Sales Order Lines

**SAP table:** RDR1  
**Bronze name:** sales_order_lines_rdr1  
**Total columns in raw:** 14

## Description

Stores the line items of sales orders (Sales Order Rows in SAP B1). Each row represents an ordered product. It has dual traceability: `BaseEntry` points to the source quote and `TrgetEntry` points to the generated invoice — a field unique to this table among the sales line tables.

## Relationships

**Parent table — join on `DocEntry`:**
- ORDR (`sales_order_ordr`) — order header

**Tables referenced per line:**
- OITM via `ItemCode` — master record of the ordered item
- OWHS via `WhsCode` — destination warehouse

**Bidirectional traceability (confirmed in the database):**
- OQUT via `BaseEntry` — quote that originated this order (164,984 rows with no BaseEntry, the rest sourced from a quote)
- OINV via `TrgetEntry` — invoice generated from this order line (166,824 distinct invoices referenced)

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Document Internal ID | doc_entry | int | rename |
| LineNum | Row Number | line_number | int | rename |
| BaseEntry | Base Document Internal ID | doc_entry_cotacao | int | rename |
| BaseLine | Base Row | quote_line_number | int | rename |
| TrgetEntry | Target Document Internal ID | doc_entry_nf_saida | int | rename |
| ItemCode | Item No. | item_code | nvarchar | rename |
| Dscription | Item/Service Description | item_description | nvarchar | rename — intentional SAP typo |
| Quantity | Quantity | quantity | decimal(18,6) | cast |
| Price | Price after Discount | unit_price | decimal(18,2) | cast |
| LineTotal | Row Total | total_linha | decimal(18,2) | cast |
| WhsCode | Warehouse Code | warehouse_code | nvarchar | rename |
| LineStatus | Row Status | line_status | nvarchar | CASE (see enums) |
| OpenQty | Open Quantity | open_quantity | decimal(18,6) | cast |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### LineStatus — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| O | Open | 1,250 |
| C | Closed | 837,179 |

## Database notes

- `OpenQty` only has a value on the 1,323 open rows (LineStatus='O') — null on closed ones. It represents the quantity not yet fulfilled by an invoice.
