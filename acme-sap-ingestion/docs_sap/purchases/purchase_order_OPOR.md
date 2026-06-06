# OPOR — Purchase Order (header)

**SAP table:** OPOR  
**Bronze name:** purchase_order_opor  
**Total raw columns:** 13

## Description

Stores the headers of purchase orders (Purchase Order in SAP B1). Each row represents an order issued to a vendor. The purchase order originates the A/P invoice (OPCH) and may have been generated from a purchase requisition (OPRQ).

OPOR has no `UpdateTS` in raw — the watermark has daily precision only. SAP has this field, but it was not imported during ingestion.

## Relationships

**Child table — join on `DocEntry`:**
- POR1 (`purchase_order_lines_por1`) — item rows of the purchase order

**Parent tables — OPOR references:**
- OBPL via `BPLId` — issuing branch
- OUSR via `UserSign` — user responsible for the order

**Traceability:**
- OPRQ via `POR1.BaseEntry` where `POR1.BaseType = 1470000113` — purchase requisition that originated the order

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Numerator | doc_entry | int | rename |
| DocNum | Document Number | purchase_order_number | int | rename |
| DocDate | Posting Date | issue_date | date | cast |
| CreateDate | Creation Date | creation_date | date | cast |
| UpdateDate | Date of Update | updated_date | date | cast — watermark |
| DocStatus | Document Status | document_status | nvarchar | CASE (see enums) |
| CANCELED | Canceled | cancelado | nvarchar | CASE (see enums) |
| CardCode | Customer/Vendor Code | supplier_code | nvarchar | rename |
| CardName | Customer/Vendor Name | supplier_name | nvarchar | rename |
| DocTotal | Document Total | total_documento | decimal(18,2) | cast |
| BPLId | Branch | id_filial | int | rename |
| UserSign | User Signature | user_code | smallint | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### DocStatus — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| O | Open | 5,146 |
| C | Closed | 14,729 |

### CANCELED — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| N | No | 18,876 |
| Y | Yes | 999 |

> OPOR has no 'C' (Cancellation) value in the database — only Y and N, unlike OPCH/OINV/ORIN.

## Database notes

- 19,875 purchase orders in total
- `UpdateTS` exists in SAP but was not imported into raw — watermark with daily granularity only
- Join with POR1 confirmed: 19,850 orders have rows
