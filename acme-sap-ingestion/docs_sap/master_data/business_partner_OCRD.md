# OCRD — Business Partner

**SAP table:** OCRD  
**Bronze name:** business_partner_ocrd  
**Total columns in raw:** 16

## Description

Stores the business partner master data (Business Partners in SAP B1). Each row represents a customer, vendor or lead. It is the reference table for the `CardCode` and `CardName` used in the headers of every sales and purchase document (OINV, ORDR, OQUT, ORIN, OPCH, OPOR).

## Relationships

**Parent tables — OCRD references:**
- OCRG via `GroupCode` — business partner group
- OSLP via `SlpCode` — salesperson responsible for the partner

**Tables that reference OCRD:**
- OINV, ORDR, OQUT, ORIN via `CardCode` — sales documents
- OPCH, OPOR via `CardCode` — purchase documents

## Column mapping

Source of the descriptions: SAP Business One SDK 10.0 — confirmed via `/Business_Partners/OCRD.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| CardCode | BP Code | partner_code | nvarchar | rename — primary key |
| CardFName | Foreign Name | partner_name | nvarchar | rename |
| UpdateDate | Date of Update | updated_date | date | cast |
| UpdateTS | Update Full Time | update_ts | int | rename — second-level watermark, do not convert |
| GroupCode | Group Code | group_code | smallint | rename |
| CardType | BP Type | partner_type | nvarchar | CASE (see enums) |
| Balance | Account Balance | balance | decimal(18,2) | cast |
| Password | Password | senha | nvarchar | rename |
| LicTradNum | Federal Tax ID | cpf_cnpj | nvarchar | rename |
| SlpCode | Sales Employee Code | salesperson_code | int | rename |
| U_PARTNER_SHOW_IN_BI | — | aparecer_bi | nvarchar | CASE: 'S'→'yes', 'N'→'no' |
| U_PRESALE | — | canal_prevenda | nvarchar | CASE (see enums) |
| U_franchiseName | — | franchise_name | nvarchar | rename — name of the franchise associated with the partner |
| CardName | BP Name | commercial_partner_name | nvarchar | rename — commercial name; CardFName is the foreign name |
| CreateDate | Creation Date | registration_date | date | cast |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### CardType — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| C | Customer | 71,001 |
| S | Vendor | 1,620 |
| L | Lead | 1 |

### U_PARTNER_SHOW_IN_BI — source: database + PO
| Code | Meaning | Count in database |
|---|---|---|
| S | Yes | 72,607 |
| N | No | 15 |

### U_PRESALE — source: PO
| Code | Meaning | Count in database |
|---|---|---|
| N | No | 68,402 |
| I | Internal (Google) | 1,805 |
| P | CRM | 2,415 |
| PS | CRM Steel Frame | — |
| PP | CRM Flooring | — |
| PD | CRM Drywall | — |
| PA | CRM Acoustics | — |
| PQ | CRM Mortar | — |
| PE | CRM Window Frames | — |


## Database notes

- 72,622 partners registered; predominantly customers (71,001 = 97.8%)
- `Password` imported into raw — consider masking it in bronze for security reasons
- `LicTradNum` stores either CPF or CNPJ depending on the person type — no format standardization in SAP
- `CardName` and `CardFName` are distinct fields: `CardFName` is the foreign name (filled in for 72,622), `CardName` is the commercial name (filled in for only 88) — in bronze renamed to `partner_name` and `commercial_partner_name` respectively
