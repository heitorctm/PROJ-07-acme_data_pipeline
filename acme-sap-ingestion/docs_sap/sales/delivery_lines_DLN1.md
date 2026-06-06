# DLN1 — Delivery Lines

**SAP table:** DLN1  
**Bronze name:** delivery_lines_dln1  
**Total columns in raw:** 10

## Description

Stores the line items of deliveries (Delivery Rows in SAP B1). Each row represents a delivered product. The `BaseType` field reveals the source document — predominantly OINV (13) and ODLN (15), with a small volume from ORDR (17) and OQUT (23).

## Relationships

**Parent table — join on `DocEntry`:**
- ODLN (`delivery_odln`) — delivery header

**Tables referenced per line:**
- OITM via `ItemCode` — master record of the delivered item
- OWHS via `WhsCode` — source warehouse of the outflow

**Traceability (via BaseEntry + BaseType):**
- OINV via `BaseEntry` where `BaseType = 13` — sales invoice that originated this line (90,298 rows)
- ODLN via `BaseEntry` where `BaseType = 15` — another delivery as base (6,899 rows)
- ORDR via `BaseEntry` where `BaseType = 17` — sales order as base (24 rows)
- OQUT via `BaseEntry` where `BaseType = 23` — quote as base (5 rows)
- no source: `BaseType = -1` (1,884 rows)

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Document Internal ID | doc_entry | int | rename |
| LineNum | Row Number | line_number | int | rename |
| BaseEntry | Base Document Internal ID | doc_entry_origem | int | rename |
| BaseLine | Base Row | source_line_number | int | rename |
| BaseType | Base Document Type | source_document_type | int | CASE (see enums) |
| ItemCode | Item No. | item_code | nvarchar | rename |
| WhsCode | Warehouse Code | warehouse_code | nvarchar | rename |
| Quantity | Quantity | quantity | decimal(18,6) | cast |
| LineStatus | Row Status | line_status | nvarchar | CASE (see enums) |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### LineStatus — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| O | Open | 585 |
| C | Closed | 98,525 |

### BaseType — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| 13 | A/R Invoice (OINV) | 90,298 |
| 15 | Delivery (ODLN) | 6,899 |
| -1 | No base document | 1,884 |
| 17 | Sales Order (ORDR) | 24 |
| 23 | Sales Quotation (OQUT) | 5 |

## Database notes

- 99,110 rows across 21,469 distinct deliveries
- Dominant pattern: delivery line originated from an invoice (BaseType 13 = 91% of rows) — the reverse of the expected flow (ORDR → ODLN → OINV); this indicates that part of the deliveries is generated retroactively from the invoice
