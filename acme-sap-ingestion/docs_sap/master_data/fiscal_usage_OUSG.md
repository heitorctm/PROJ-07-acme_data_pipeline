# OUSG — Fiscal Usage of the Invoice

**SAP table:** OUSG  
**Bronze name:** fiscal_usage_ousg  
**Total columns in raw:** 3

## Description

Stores the master data of fiscal usages/purposes of invoices (Usage of Nota Fiscal in SAP B1). Each row represents a possible fiscal purpose for a document. It is referenced by the sales and purchase fiscal-extension tables via `MainUsage`/`Usage`.

## Relationships

**Tables that reference OUSG:**
- INV12 (`sales_invoice_usage_inv12`) via `MainUsage` — fiscal usage of the outbound invoice
- RIN12 (`sales_return_usage_rin12`) via `MainUsage` — fiscal usage of the return
- QUT12 (`quote_usage_qut12`) via `MainUsage` — fiscal usage of the quotation
- PCH12 (`purchase_invoice_usage_pch12`) via `MainUsage` — fiscal usage of the inbound invoice
- INV1 (`sales_invoice_lines_inv1`) via `Usage` — fiscal usage of the outbound invoice line
- PCH1 (`purchase_invoice_lines_pch1`) via `Usage` — fiscal usage of the inbound invoice line

## Column mapping

Source of the descriptions: SAP Business One SDK 10.0 — confirmed via `/Administration/OUSG.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| ID | Usage ID | id_uso | int | rename — primary key |
| Usage | Usage | usage_description | nvarchar | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Registered usages

| ID | Usage |
|---|---|
| 1 | Industrialization |
| 3 | Commercial Purchase |
| 5 | Transfer |
| 6 | Repair or maintenance |
| 7 | Consumption Purchase |
| 8 | Fixed Asset Purchase |
| 9 | Sale Own Product |
| 10 | Sale Acquired 3rd Pty |
| 11 | Demonstration |
| 12 | Donation or gift |
| 13 | Electric Energy |
| 14 | Telephony/Internet |
| 15 | Food Purchase |
| 16 | Office Supplies |
| 17 | Cleaning Supplies |
| 18 | Service Provision |
| 19 | Expenses |
| 20 | Future.Delivery.Sale |
| 21 | Future Delivery Ship. |
| 22 | Sale End Consumer |
| 23 | Advance Payment |
| 24 | Goods Return |
| 26 | Transfer Return |
| 27 | Use/Consumption Write |
| 28 | Advance Return |
| 29 | Future Delivery Purch |
| 30 | Future Deliv Purchase |
| 31 | Consignment Shipment |
| 32 | Freight Complement |
| 33 | Tax Complement |
| 34 | Quantity Complement |
| 35 | Value Complement |
| 36 | Future Deliv Return |
| 37 | Order Sale |
| 38 | Order Purchase |
| 39 | Advance Reversal |
| 40 | Doubtful Advance |
| 41 | Service Expense |
| 42 | Delivery to Order |
| 43 | Tax Compl Inbound |
| 44 | Loan or lease |
| 45 | Loss/Damage Writeoff |
| 46 | Sale with Suframa |
| 47 | Exchange |
| 48 | Non-Operating Income |
| 49 | Loans and Borrowings |
| 50 | Delivery Return |
| 51 | Sale for resale |
| 52 | Sale for industry |
| 53 | Use and consumption |
| 54 | Ret. Industrial Sale |
| 55 | Inbound Order Sale |
| 56 | Order Sale Consumer |
| 57 | Trade Show Shipment |
| 58 | Other Outbound |
| 59 | Third-Party Possession |
| 60 | Renegotiation |

## Database notes

- 57 usages registered (non-sequential IDs — IDs 2, 4, 25 are missing)
- Most frequent usages in sales: ID 10 (INV12), ID 24 (RIN12)
- Most frequent usages in purchases: ID 19 (PCH12)
