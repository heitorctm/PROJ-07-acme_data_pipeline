# ODLN — Delivery (header)

**SAP table:** ODLN  
**Bronze name:** delivery_odln  
**Total columns in raw:** 11

## Description

Stores the headers of shipments/deliveries (Delivery in SAP B1). Each row represents a delivery of goods to the customer. It is the document that formalizes the physical removal of stock — generated from a sales order (ORDR) and preceding or accompanying the issuance of the invoice (OINV).

Unlike the other sales headers, ODLN has no `UpdateTS` — its watermark is composed solely of `UpdateDate` (daily precision).

## Relationships

**Child table — join on `DocEntry`:**
- DLN1 (`delivery_lines_dln1`) — delivery line items

**Traceability (via DLN1):**
- ORDR via `DLN1.BaseEntry` where `DLN1.BaseType = 17` — sales order that originated the delivery

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Internal Number | doc_entry | int | rename |
| DocNum | Document Number | delivery_number | int | rename |
| DocDate | Posting Date | issue_date | date | cast |
| CreateDate | Creation Date | creation_date | date | cast |
| UpdateDate | Date of Update | updated_date | date | cast — watermark |
| DocStatus | Document Status | document_status | nvarchar | CASE (see enums) |
| CANCELED | Canceled | cancelado | nvarchar | CASE (see enums) |
| CardCode | Customer/Vendor Code | customer_code | nvarchar | rename |
| CardName | Customer/Vendor Name | customer_name | nvarchar | rename |
| BPLId | Branch | id_filial | int | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### DocStatus — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| O | Open | 717 |
| C | Closed | 20,755 |

### CANCELED — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| N | No | 19,301 |
| Y | Yes | 1,085 |
| C | Cancellation | 1,086 |

## Database notes

- 21,472 deliveries in total, covering the period 2023-07-12 to 2026-05-06
- ODLN has no `UpdateTS` — the only sales header without a second-level watermark; incremental granularity is daily
- Join with DLN1 confirmed: up to 41 lines per delivery (DocEntry 18833)
