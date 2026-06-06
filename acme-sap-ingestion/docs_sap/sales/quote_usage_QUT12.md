# QUT12 — Sales Quote Fiscal Extension

**SAP table:** QUT12  
**Bronze name:** quote_usage_qut12  
**Total columns in raw:** 3

## Description

Stores the main fiscal usage/destination of sales quotes (Sales Quotation Tax Extension in SAP B1). Each row associates a quote with its main fiscal usage code. The code references the OUSG table, which holds the master record of operation usages.

## Relationships

**Parent table — join on `DocEntry`:**
- OQUT (`quote_oqut`) — quote header

**Referenced tables:**
- OUSG via `MainUsage` — master record of fiscal usages/destinations of the operation

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Document Internal ID | doc_entry | int | rename |
| MainUsage | Main Usage Code of Document | main_usage | int | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- Most records have no usage defined: null (302,384)
- Most frequent codes: 10 (12,805), 5 (462), 20 (332), 22 (264)
- The meaning of each code is in the OUSG table (`ousg_usos_operacao`)
