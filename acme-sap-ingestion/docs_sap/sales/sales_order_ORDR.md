# ORDR — Sales Order (header)

**SAP table:** ORDR  
**Bronze name:** sales_order_ordr  
**Total columns in raw:** 17

## Description

Stores the headers of sales orders (Sales Order in SAP B1). Each row represents an order. The order is generated from a quote (OQUT) and originates an invoice (OINV). Because it is `incremental_upsert`, the raw layer always keeps the most recent state of each order — updates and cancellations overwrite the existing record via MERGE on the `DocEntry` key.

## Relationships

ORDR is the intermediate document of the sales cycle — generated after a quote is approved and before the invoice is issued.

**Child tables — join on `DocEntry`:**
- RDR1 (`sales_order_lines_rdr1`) — order line items

**Parent tables — ORDR references:**
- OSLP via `SlpCode` — responsible sales employee
- OBPL via `BPLId` — issuing branch

**Traceability (confirmed in the database):**
- OQUT via `RDR1.BaseEntry` where `RDR1.BaseType = 23` — quote that originated the order
- OINV via `INV1.BaseEntry` where `INV1.BaseType = 17` — invoice generated from this order

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Internal Number | doc_entry | int | rename |
| DocNum | Document Number | order_number | int | rename |
| DocDate | Posting Date | issue_date | date | cast |
| DocDueDate | Due Date | expected_delivery_date | date | cast |
| CreateDate | Creation Date | creation_date | date | cast |
| UpdateDate | Date of Update | updated_date | date | cast |
| UpdateTS | Update Full Time | update_ts | int | rename — second-level watermark, do not convert |
| DocStatus | Document Status | document_status | nvarchar | CASE (see enums) |
| CANCELED | Canceled | cancelado | nvarchar | CASE (see enums) |
| CardCode | Customer/Vendor Code | customer_code | nvarchar | rename |
| CardName | Customer/Vendor Name | customer_name | nvarchar | rename |
| SlpCode | Sales Employee | salesperson_code | int | rename |
| BPLId | Branch | id_filial | int | rename |
| DocTotal | Document Total | total_documento | decimal(18,2) | cast |
| GrosProfit | Gross Profit | lucro_bruto | decimal(18,2) | cast |
| VatSum | Total Tax | total_impostos | decimal(18,2) | cast |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### DocStatus — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| O | Open | 423 |
| C | Closed | 224,793 |

### CANCELED — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| N | No | 168,288 |
| Y | Yes | 56,928 |

> Unlike OINV and ORIN, ORDR does not have the value 'C' (Cancellation) — neither in the SDK nor in the database.
