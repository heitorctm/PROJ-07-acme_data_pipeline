# QUT1 — Sales Quote Lines

**SAP table:** QUT1  
**Bronze name:** quote_lines_qut1  
**Total columns in raw:** 21

## Description

Stores the line items of sales quotes (Sales Quotation Rows in SAP B1). Each row represents a quoted product or service. Always linked to OQUT through `DocEntry`. The quote does not originate from any prior document — every row has `BaseType = -1`.

## Relationships

**Parent table — join on `DocEntry`:**
- OQUT (`quote_oqut`) — quote header

**Tables referenced per line:**
- OITM via `ItemCode` — master record of the quoted item
- OWHS via `WhsCode` — source warehouse
- OUSG via `Usage` — fiscal usage/destination of the operation

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
| INMPrice | Item's Last Sales Price | inventory_cost_price | decimal(18,2) | cast |
| LineStatus | Row Status | line_status | nvarchar | CASE (see enums) |
| Usage | Usage Code for Document | id_uso | int | rename |
| CFOPCode | CFOP Code for Document | cfop | nvarchar | rename |
| WhsCode | Warehouse Code | warehouse_code | nvarchar | rename |
| BaseEntry | Base Document Internal ID | doc_entry_origem | int | rename |
| BaseType | Base Document Type | source_document_type | int | rename — always -1 in this table |
| U_BDI_PRICE | — | bdi_price | decimal(18,2) | normalize_brazilian_decimal — value stored with a decimal comma in SAP |
| U_COST_PRICE | — | cost_price | decimal(18,2) | normalize_brazilian_decimal — value stored with a decimal comma in SAP |
| U_MARGIN | — | margin | decimal(18,4) | normalize_brazilian_decimal — value stored with a decimal comma in SAP |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### LineStatus — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| O | Open | 583,804 |
| C | Closed | 1,065,807 |

### BaseType — source: SAP SDK + database
| Code | SAP meaning | Count in database |
|---|---|---|
| -1 | No base document | 1,649,611 |

> The quote is always the first document of the cycle — it never originates from another document, so BaseType is always -1.

### U_ fields — price composition factors

Same fields present in INV1 — same meaning and transformation.

| Field | Bronze name | Description |
|---|---|---|
| U_BDI_PRICE | bdi_price | BDI price per unit — internal basis for margin calculation |
| U_COST_PRICE | cost_price | Cost price per unit for contribution-margin calculation |
| U_MARGIN | margin | Line contribution margin as calculated and maintained by SAP |
