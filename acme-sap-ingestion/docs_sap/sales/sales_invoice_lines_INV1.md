# INV1 — Sales Invoice Lines

**SAP table:** INV1  
**Bronze name:** sales_invoice_lines_inv1  
**Total columns in raw:** 21

## Description

Stores the line items of sales invoices (A/R Invoice Rows in SAP B1). Each row represents a product or service billed within an invoice. Always linked to OINV through `DocEntry`.

## Relationships

INV1 is the line-item table of OINV. Each line references the source document via `BaseEntry + BaseType`, allowing you to trace which document the invoice was generated from.

**Parent table — join on `DocEntry`:**
- OINV (`sales_invoice_oinv`) — invoice header

**Tables referenced per line:**
- OITM via `ItemCode` — master record of the billed item
- OWHS via `WhsCode` — source warehouse
- OUSG via `Usage` — fiscal usage/destination of the operation

**Source traceability via `BaseEntry + BaseType` (confirmed in the database):**
- ORDR (`BaseType = 17`) — line originated from a sales order (709,086 rows)
- ORIN (`BaseType = 13`) — line originated from a return (50,814 rows)
- OQUT (`BaseType = 23`) — line originated directly from a quote (20,092 rows)
- No source (`BaseType = -1`) — direct entry with no base document (57,860 rows)

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
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### LineStatus — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| O | Open | 731,534 |
| C | Closed | 106,318 |

### BaseType — source: SAP SDK + database
| Code | SAP meaning | Count in database |
|---|---|---|
| 17 | Sales Order (ORDR) | 709,086 |
| -1 | No base document | 57,860 |
| 13 | A/R Credit Memo (ORIN) | 50,814 |
| 23 | Sales Quotation (OQUT) | 20,092 |

> Other values defined in the SDK but not observed in the database: 0, 15 (Delivery), 67 (Inventory Transfer).

### U_ fields — price composition factors

All three fields are stored as text with a decimal comma in SAP — they require `TRY_CAST(REPLACE(val, ',', '.') as decimal)` in staging.

| Field | Bronze name | Description |
|---|---|---|
| U_BDI_PRICE | bdi_price | BDI price per unit — internal basis for margin calculation |
| U_COST_PRICE | cost_price | Cost price per unit for contribution-margin calculation |
| U_MARGIN | margin | Line contribution margin as calculated and maintained by SAP |
