# PCH1 — A/P Invoice Lines

**SAP table:** PCH1  
**Bronze name:** purchase_invoice_lines_pch1  
**Total raw columns:** 15

## Description

Stores the item rows of A/P invoices (A/P Invoice Rows in SAP B1). Each row represents a product or service received from the vendor. Unlike the sales rows (INV1/RIN1), PCH1 has no `BaseEntry`/`BaseType` in raw — traceability to the purchase order must be done via OPOR directly.

## Relationships

**Parent table — join on `DocEntry`:**
- OPCH (`purchase_invoice_opch`) — A/P invoice header

**Tables referenced per row:**
- OITM via `ItemCode` — master record of the received item
- OWHS via `WhsCode` — destination warehouse of the receipt
- OUSG via `Usage` — tax usage code of the row

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Document Internal ID | doc_entry | int | rename |
| LineNum | Row Number | line_number | int | rename |
| ItemCode | Item No. | item_code | nvarchar | rename |
| WhsCode | Warehouse Code | warehouse_code | nvarchar | rename |
| AcctCode | Account Code | ledger_account_code | nvarchar | rename |
| Usage | Usage Code for Document | id_uso | int | rename |
| Quantity | Quantity | quantity | decimal(18,6) | cast |
| Price | Price | unit_price | decimal(18,2) | cast |
| PriceBefDi | Unit Price | price_before_discount | decimal(18,2) | cast |
| LineTotal | Row Total | total_linha | decimal(18,2) | cast |
| VatSum | Total Tax | total_impostos | decimal(18,2) | cast |
| INMPrice | Item's Last Sales Price | inventory_cost_price | decimal(18,2) | cast |
| DiscPrcnt | Discount % per Row | percentual_desconto | decimal(18,4) | cast |
| BaseEntry | Base Document Internal ID | doc_entry_pedido_compra | int | rename — DocEntry of the source OPOR |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 168,514 rows for 72,755 distinct invoices
- `Usage` references OUSG — 5 distinct values in the database: 5 (63k), 3 (52k), 19 (41k), 38 (8k), 18 (1k)
- `BaseEntry` populated in 128 rows (49 distinct orders) — traces the OPOR that originated the A/P invoice; null in most cases indicates invoices with no prior purchase order
