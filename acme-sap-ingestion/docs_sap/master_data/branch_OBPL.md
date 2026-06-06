# OBPL — Branch

**SAP table:** OBPL  
**Bronze name:** branch_obpl  
**Total columns in raw:** 4

## Description

Stores the master data of branches/business units (Branch in SAP B1). Each row represents an operational branch of Acme or a company in the group. It is referenced by the headers of every sales and purchase document via `BPLId`.

The `U_NOMENCLATURE` field stores the short commercial name of the branch — more readable than `BPLName` for use in reports.

## Relationships

**Tables that reference OBPL:**
- OINV, ORDR, OQUT, ORIN via `BPLId` — branch issuing the sales document
- OPCH, OPOR via `BPLId` — branch issuing the purchase document
- OPRQ via `BPLId` — requesting branch

## Column mapping

Source of the descriptions: SAP Business One SDK 10.0 — confirmed via `/Business_Partners/OBPL.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| BPLId | Branch ID | id_filial | int | rename — primary key |
| BPLName | Branch Name | branch_name | nvarchar | rename |
| U_NOMENCLATURE | — | nomenclature | nvarchar | rename — short commercial name of the branch, preferred for reports |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Registered branches

| BPLId | BPLName | U_NOMENCLATURE |
|---|---|---|
| 1 | ACME DRYWALL FRANCHISING LTDA | ACME DRYWALL |
| 2 | ACME RETAIL CITY A | MEGA STORE CITY A - ST1 |
| 3 | ACME RETAIL CITY B | MEGA STORE CITY B - ST2 |
| 4 | ACME RETAIL CITY C | MEGA STORE CITY C - ST3 |
| 5 | ACME RETAIL CITY D | MEGA STORE CITY D |
| 6 | ACME RETAIL CITY E | MEGA STORE CITY E |
| 7 | ACME RETAIL CITY F | MEGA STORE CITY F |
| 8 | DOWNTOWN - FRANCHISE 01 | DOWNTOWN |
| 9 | NORTHSIDE - FRANCHISE 02 | NORTHSIDE |
| 10 | WESTFIELD - FRANCHISE 03 | WESTFIELD |
| 11 | CITY CENTER - FRANCHISE 04 | CITY CENTER |
| 14 | MARKETING AGENCY LTD | MKT AGENCY |
| 15 | ACME RETAIL CITY G | MEGA STORE CITY G |
| 16 | ACME DRYWALL HIGHLANDS | HIGHLANDS - ST4 |
| 17 | SUPPLY CHAIN LTD | SUPPLY CHAIN |
| 18 | ACME RETAIL CITY H | MEGA STORE CITY H |
| 19 | EASTGATE - FRANCHISE 05 | EASTGATE |
| 20 | SOUTHBAY - FRANCHISE 06 | SOUTHBAY |
| 21 | RIVERSIDE - FRANCHISE 07 | RIVERSIDE |
| 22 | LAKEVIEW - FRANCHISE 08 | LAKEVIEW |
| 23 | HILLCREST - FRANCHISE 09 | HILLCREST |
| 24 | SSC | SSC |
| 25 | LOGISTICS CO | LOG |
| 26 | PARK | PARK |
| 27 | TELESALES | TELESALES |
| 28 | OAKWOOD - INSIDE/01 | OAKWOOD - INSIDE/A |
| 29 | MAPLEWOOD | MAPLEWOOD |
| 30 | GREENFIELD | GREENFIELD |
| 31 | TRAINING CENTER | TRAINING CENTER |
| 32 | CITY A STATUS | CITY A STATUS |
| 33 | FAIRFIELD | FAIRFIELD |
| 34 | BROOKHAVEN | BROOKHAVEN |
| 35 | STEEL CO | STEEL CO |
| 36 | FRONTIER | FRONTIER |
| 37 | ACME RETAIL CITY I | MEGA STORE CITY I |
| 38 | ACME RETAIL CITY J | MEGA STORE CITY J |
| 39 | ACME RETAIL CITY K | MEGA STORE CITY K |
| 40 | SUPPLY CHAIN ST4 | SUPPLY CHAIN - ST4 |
| 41 | ACME RETAIL CITY L | MEGA STORE - ST4 |
| 42 | ACME RETAIL CITY M | MEGA STORE - ST4 NORTH |
| 43 | ACME RETAIL CITY N | MEGA STORE CITY N - ST1 |

## Database notes

- 41 branches registered (BPLId 1–43, missing 12 and 13)
- `U_NOMENCLATURE` is the preferred short name for use in reports — more readable than `BPLName`
- BPLId 1 = headquarters/franchisor; BPLIds 2–7 = company-owned Mega Stores; the rest = franchises and support units
