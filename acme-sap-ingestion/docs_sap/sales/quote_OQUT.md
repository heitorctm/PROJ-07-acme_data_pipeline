# OQUT — Sales Quote (header)

**SAP table:** OQUT  
**Bronze name:** quote_oqut  
**Total columns in raw:** 24

> `Max1099` exists in raw but is not documented — a U.S. tax field unused in Brazil, kept only because it is referenced in the `vw_sales_profit_ranking` view.

## Description

Stores the headers of sales quotes (Sales Quotation in SAP B1). Each row represents a quote sent to the customer. The quote is the first document of the sales cycle — when approved, it originates an order (ORDR) or an invoice directly (OINV). Because it is `incremental_upsert`, the raw layer always keeps the most recent state of each quote — updates and cancellations overwrite the existing record via MERGE on the `DocEntry` key.

## Relationships

OQUT is the initial document of the sales cycle. When approved by the customer, it can originate an order (ORDR) or an invoice directly (OINV via INV1.BaseType=23).

**Child tables — join on `DocEntry`:**
- QUT1 (`quote_lines_qut1`) — quote line items
- QUT12 (`quote_usage_qut12`) — quote fiscal extension

**Parent tables — OQUT references:**
- OSLP via `SlpCode` — responsible sales employee
- OBPL via `BPLId` — issuing branch
- NFN1 via `SeqCode` — document series

**Target traceability (confirmed in the database via INV1 and RDR1):**
- ORDR via `RDR1.BaseEntry` where `RDR1.BaseType = 23` — order generated from this quote
- OINV via `INV1.BaseEntry` where `INV1.BaseType = 23` — invoice generated directly from this quote

## Column mapping

Source of descriptions: SAP Business One SDK 10.0. `U_` fields are custom — description pending definition by the business area.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Internal Number | doc_entry | int | rename |
| DocNum | Document Number | quote_number | int | rename |
| DocDate | Posting Date | issue_date | date | cast |
| DocDueDate | Due Date | expiration_date | date | cast |
| CreateDate | Creation Date | creation_date | date | cast |
| UpdateDate | Date of Update | updated_date | date | cast |
| UpdateTS | Update Full Time | update_ts | int | rename — second-level watermark, do not convert |
| DocStatus | Document Status | document_status | nvarchar | CASE (see enums) |
| CANCELED | Canceled | cancelado | nvarchar | CASE (see enums) |
| CardCode | Customer/Vendor Code | customer_code | nvarchar | rename |
| CardName | Customer/Vendor Name | customer_name | nvarchar | rename |
| SlpCode | Sales Employee | salesperson_code | int | rename |
| BPLId | Branch | id_filial | int | rename |
| SeqCode | Sequence Code | series_code | smallint | rename |
| PeyMethod | Payment Method | metodo_pagamento | nvarchar | rename |
| DocTotal | Document Total | total_documento | decimal(18,2) | cast |
| DocTotalSy | Document Total (SC) | total_documento_moeda_sistema | decimal(18,2) | cast |
| GrosProfit | Gross Profit | lucro_bruto | decimal(18,2) | cast |
| DiscSum | Total Discount | desconto_cabecalho | decimal(18,2) | cast |
| VatSum | Total Tax | total_impostos | decimal(18,2) | cast |
| U_LOAD_KIT | — | kit_carga | nvarchar | rename — retail/wholesale translation done in int |
| U_Store | — | store_code | nvarchar | rename — references @STORES.Code |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### DocStatus — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| O | Open | 94,057 |
| C | Closed | 222,317 |

### CANCELED — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| N | No | 311,780 |
| Y | Yes | 4,594 |

> The value 'C' (Cancellation) is defined in the SDK but does not appear in the OQUT database.

### U_LOAD_KIT (kit_carga) — source: business owner
| Code | Meaning | Count in database |
|---|---|---|
| N | Retail | 286,217 |
| S | Wholesale | 16,225 |
| P | Not filled in | 13,932 |
