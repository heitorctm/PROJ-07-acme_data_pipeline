# ORIN — Sales Invoice Return (header)

**SAP table:** ORIN  
**Bronze name:** sales_return_orin  
**Total columns in raw:** 29

## Description

Stores the headers of sales invoice returns (A/R Credit Memo in SAP B1). Each row represents a return document issued by the customer. The return references the original invoice via `RIN1.BaseEntry`. Because it is `incremental_upsert`, the raw layer always keeps the most recent state of each return — updates and cancellations overwrite the existing record via MERGE on the `DocEntry` key.

## Relationships

ORIN is generated when a customer returns goods from an OINV. Traceability to the original invoice is established through the line items (RIN1).

**Child tables — join on `DocEntry`:**
- RIN1 (`sales_return_lines_rin1`) — return line items
- RIN3 (`sales_return_expenses_rin3`) — additional charges on the return
- RIN12 (`sales_return_usage_rin12`) — return fiscal extension
- RIN21 (`sales_return_reference_rin21`) — reference to the source fiscal document

**Parent tables — ORIN references:**
- OSLP via `SlpCode` — responsible sales employee
- OBPL via `BPLId` — issuing branch
- NFN1 via `SeqCode` — document series

**Source traceability (via RIN1, not directly on ORIN):**
- OINV via `RIN1.BaseEntry` where `RIN1.BaseType = 13` — sales invoice that originated the return (confirmed in the database)

## Column mapping

Source of descriptions: SAP Business One SDK 10.0. `U_` fields are custom — description pending definition by the business area.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Numerator | doc_entry | int | rename |
| DocNum | Document Number | return_number | int | rename |
| DocDate | Posting Date | issue_date | date | cast |
| DocDueDate | Due Date | due_date | date | cast |
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
| DocTotalSy | Document Total in SC | total_documento_moeda_sistema | decimal(18,2) | cast |
| GrosProfit | Gross Profit | lucro_bruto | decimal(18,2) | cast |
| DiscSum | Total Discount | desconto_cabecalho | decimal(18,2) | cast |
| VatSum | Total Tax | total_impostos | decimal(18,2) | cast |
| U_LOAD_KIT | — | kit_carga | nvarchar | rename — retail/wholesale translation done in int |
| U_Store | — | store_code | nvarchar | rename — references @STORES.Code |
| U_PRESALE | — | canal_prevenda | nvarchar | CASE (see enums) |
| U_FINANCE_VALIDATED | — | validado_financeiro | nvarchar | CASE (see enums) |
| U_externalTicketDate | — | external_ticket_date | date | cast |
| Serial | Serial Number | series_number | int | rename |
| U_externalTicket | — | external_ticket | nvarchar | rename — ticket code on the external ticketing platform |
| U_SHOW_IN_BI | — | aparecer_bi | nvarchar | CASE (see enums) |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### DocStatus — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| O | Open | 141 |
| C | Closed | 3,788 |

### CANCELED — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| N | No | 3,247 |
| Y | Yes | 341 |
| C | Cancellation | 341 |

### U_LOAD_KIT (kit_carga) — source: business owner
| Code | Meaning | Count in database |
|---|---|---|
| N | Retail | 2,098 |
| S | Wholesale | 220 |
| P | Not filled in | 1,611 |

### U_PRESALE (canal_prevenda) — source: business owner
| Code | Meaning | Count in database |
|---|---|---|
| N | No | 3,279 |
| P | CRM | 614 |
| I | Internal (Google) | 26 |
| PS | CRM Steel Frame | 10 |
| PD | CRM Drywall | — |
| PP | CRM Flooring | — |
| PA | CRM Acoustics | — |
| PQ | CRM Mortar | — |
| PE | CRM Frames | — |

### U_FINANCE_VALIDATED (validado_financeiro) — source: business owner
| Code | Meaning | Count in database |
|---|---|---|
| N | Not validated | 3,911 |
| S | Validated | 18 |
| P | Pending | — |

### U_SHOW_IN_BI (aparecer_bi) — source: database
| Code | Meaning | Count in database |
|---|---|---|
| N | No | 22 |
| null | — | 3,929 |

> In ORIN the value 'S' does not appear in the database — unlike OINV, where 'S' is predominant.
