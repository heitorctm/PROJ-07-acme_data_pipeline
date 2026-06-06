# @STORES — Store / Sales Channel

**SAP table:** @STORES  
**Bronze name:** store  
**Total columns in raw:** 3

## Description

Custom table (User-Defined Table in SAP B1) that stores the master data of Acme's stores and sales channels. The `Code` of this table is referenced by the `U_Store` field present in OINV, OQUT, ORIN, OPCH and OSLP — identifying the store or channel responsible for each document or salesperson.

No documentation in the SAP SDK — table created by Acme.

## Relationships

**Tables that reference @STORES via `U_Store` / `U_STORE`:**
- OINV (`sales_invoice_oinv`) — store of the outbound invoice
- OQUT (`quote_oqut`) — store of the quotation
- ORIN (`sales_return_orin`) — store of the return
- OPCH (`purchase_invoice_opch`) — store of the inbound invoice
- OSLP (`salesperson_oslp`) — store of the salesperson
- OWHS (`warehouse_owhs`) — store of the warehouse

## Column mapping

Source: raw database (no SDK — custom table).

| Raw column | Bronze name | Bronze type | Transformation |
|---|---|---|---|
| Code | store_code | nvarchar | rename — primary key |
| Name | store_name | nvarchar | rename |
| _ingestao_em | _ingestao_em | datetime2 | rename — ingestion audit column |

## Registered stores

| Code | Name |
|---|---|
| 01 | DOWNTOWN |
| 02 | OAKWOOD |
| 03 | NORTHSIDE |
| 04 | RIVERTON |
| 05 | LAKEVIEW |
| 06 | CITY CENTER |
| 07 | FRANCHISE |
| 08 | REGION-1 INSIDE SALES |
| 09 | EASTGATE |
| 10 | STATE A |
| 11 | MEGA STORE CITY C - ST3 |
| 12 | MEGA STORE CITY D |
| 13 | MEGA STORE CITY A - ST1 |
| 14 | MEGA STORE CITY E |
| 15 | EXECUTIVE BOARD |
| 16 | MEGA STORE CITY B - ST2 |
| 17 | SOUTHBAY |
| 18 | RIVERSIDE |
| 19 | BAYSIDE |
| 20 | HILLCREST |
| 21 | ACME DRYWALL |
| 22 | PIONEER |
| 23 | TELESALES |
| 24 | HIGHLANDS - ST4 |
| 25 | SUPPLY CHAIN |
| 26 | REGION-1 EXECUTIVE B2B |
| 27 | CITY A STATUS |
| 28 | MEGA STORE CITY K |
| 29 | WHOLESALE ST2 |
| 30 | REGION-2 EXECUTIVE B2B |
| 31 | ST3 WHOLESALE |
| 32 | REGION-3 EXECUTIVE B2B |
| 33 | REGION-4 EXECUTIVE B2B |
| 34 | REGION-5 EXECUTIVE B2B |
| 35 | SSC |
| 36 | REGION-6 EXECUTIVE B2B |
| 37 | ACME HOMES |
| 38 | ACME PROJECTS |
| 39 | REGION-7 EXECUTIVE B2B |
| 40 | SUPPLY CHAIN - ST4 |
| 41 | MEGA STORE - ST4 |
| 42 | SUPPLY CHAIN - REGION-1 |
| 43 | MEGA STORE - ST4 NORTH |
| 44 | MARKETPLACE |
| 45 | STEEL CONNECT |

## Database notes

- 45 stores/channels registered
- Includes physical stores, mega stores, digital channels (MARKETPLACE), per-region B2B teams and internal units (SSC, EXECUTIVE BOARD, SUPPLY CHAIN)
- `Code` is a numeric string with a leading zero (e.g. '01', '07') — when joining, use `CAST` or compare as nvarchar
