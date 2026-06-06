# RIN1 — Sales Invoice Return Lines

**SAP table:** RIN1  
**Bronze name:** sales_return_lines_rin1  
**Total columns in raw:** 22

## Description

Stores the line items of sales invoice returns (A/R Credit Memo Rows in SAP B1). Each row represents a returned product. Traceability to the source document is established via `BaseEntry + BaseType`.

## Relationships

**Parent table — join on `DocEntry`:**
- ORIN (`sales_return_orin`) — return header

**Tables referenced per line:**
- OITM via `ItemCode` — master record of the returned item
- OWHS via `WhsCode` — destination warehouse
- OUSG via `Usage` — fiscal usage/destination of the operation

**Source traceability via `BaseEntry + BaseType` (confirmed in the database):**
- OINV (`BaseType = 13`) — sales invoice that originated the return (8,055 rows)
- OINV as credit (`BaseType = 14`) — accounts-receivable credit note (1,293 rows)
- Down payment (`BaseType = 203`) — down-payment refund (676 rows)
- No source (`BaseType = -1`) — direct entry with no base document (481 rows)
- Return request (`BaseType = 234000031`) — (4 rows)

## Column mapping

Source of descriptions: SAP Business One SDK 10.0. `U_` fields are custom — description pending definition by the business area.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Document Internal ID | doc_entry | int | rename |
| LineNum | Row Number | line_number | int | rename |
| ItemCode | Item No. | item_code | nvarchar | rename |
| Dscription | Item/Service Description | item_description | nvarchar | rename — intentional SAP typo |
| Quantity | Quantity | quantity | decimal(18,6) | cast |
| Price | Price after Discount | unit_price | decimal(18,2) | cast |
| PriceBefDi | Unit Price | price_before_discount | decimal(18,2) | cast |
| DiscPrcnt | Discount % per Row | percentual_desconto | decimal(18,4) | cast |
| LineTotal | Row Total | total_linha | decimal(18,2) | cast |
| VatSum | Total Tax | total_impostos | decimal(18,2) | cast |
| INMPrice | Item's Last Sales Price (OINM) | inventory_cost_price | decimal(18,2) | cast |
| LineStatus | Row Status | line_status | nvarchar | CASE (see enums) |
| Usage | Usage Code for Document | id_uso | int | rename |
| CFOPCode | CFOP Code for Document | cfop | nvarchar | rename |
| WhsCode | Warehouse Code | warehouse_code | nvarchar | rename |
| BaseEntry | Base Document Internal ID | doc_entry_origem | int | rename |
| BaseType | Base Document Type | source_document_type | int | CASE (see enums) |
| U_BDI_PRICE | — | bdi_price | decimal(18,2) | normalize_brazilian_decimal — value stored with a decimal comma in SAP |
| U_COST_PRICE | — | cost_price | decimal(18,2) | normalize_brazilian_decimal — value stored with a decimal comma in SAP |
| U_MARGIN | — | margin | decimal(18,4) | normalize_brazilian_decimal — value stored with a decimal comma in SAP |
| ActBaseEnt | Actual Base Entry | doc_entry_origem_efetivo | int | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### LineStatus — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| O | Open | 311 |
| C | Closed | 10,198 |

### BaseType — source: SAP SDK + database
| Code | SAP meaning | Count in database |
|---|---|---|
| 13 | A/R Invoice (OINV) | 8,055 |
| 14 | A/R Credit Note | 1,293 |
| 203 | A/R Down Payment | 676 |
| -1 | No base document | 481 |
| 234000031 | A/R Return Request | 4 |

### U_ fields — price composition factors

| Field | Bronze name | Description |
|---|---|---|
| U_BDI_PRICE | bdi_price | BDI price per unit — internal basis for margin calculation |
| U_COST_PRICE | cost_price | Cost price per unit for contribution-margin calculation |
| U_MARGIN | margin | Line contribution margin as calculated and maintained by SAP |

### ActBaseEnt

`ActBaseEnt` (Actual Base Entry) is the `DocEntry` of the effective source document. It differs from `BaseEntry` when the line passed through multiple intermediate documents — it always points to the actual root document. On RIN1, it typically references the `DocEntry` of the OINV that originated the return.
