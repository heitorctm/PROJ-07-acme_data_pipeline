# OPRQ — Purchase Requisition (header)

**SAP table:** OPRQ  
**Bronze name:** purchase_requisition_oprq  
**Total raw columns:** 12

## Description

Stores the headers of purchase requisitions (Purchase Request in SAP B1). Each row represents an internal request to procure material or services, preceding the purchase order. It is the initial document of the purchasing cycle — created by a user and converted into a purchase order (OPOR) once approved.

OPRQ has no `UpdateTS` in raw — the watermark has daily precision.

## Relationships

**Child table — join on `DocEntry`:**
- PRQ1 (`purchase_requisition_lines_prq1`) — item rows of the requisition

**Parent tables — OPRQ references:**
- OBPL via `BPLId` — requesting branch
- OUSR via `UserSign` — user who created the requisition

**Traceability:**
- OPOR via `POR1.BaseEntry` where `POR1.BaseType = 1470000113` — purchase order generated from this requisition

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Numerator | doc_entry | int | rename |
| DocNum | Document Number | requisition_number | int | rename |
| DocDate | Posting Date | issue_date | date | cast |
| CreateDate | Creation Date | creation_date | date | cast |
| UpdateDate | Date of Update | updated_date | date | cast — watermark |
| DocStatus | Document Status | document_status | nvarchar | CASE (see enums) |
| CANCELED | Canceled | cancelado | nvarchar | CASE (see enums) |
| UserSign | User Signature | user_code | smallint | rename |
| BPLId | Branch | id_filial | int | rename |
| U_externalTicket | — | external_ticket | nvarchar | rename — ticket code on the external ticketing platform |
| U_externalTicketDate | — | external_ticket_date | date | cast |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### DocStatus — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| O | Open | 330 |
| C | Closed | 948 |

### CANCELED — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| N | No | 649 |
| Y | Yes | 629 |

> OPRQ has no 'C' (Cancellation) value in the database — only Y and N.

## Database notes

- 1,278 requisitions in total — lower volume than OPOR (19,875), indicating that most purchase orders are created directly without a formal requisition
- Join with PRQ1 confirmed: 1,278 requisitions with rows, 8,662 rows in total
