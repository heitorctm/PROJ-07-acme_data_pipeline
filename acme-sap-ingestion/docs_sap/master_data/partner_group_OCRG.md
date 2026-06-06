# OCRG — Business Partner Group

**SAP table:** OCRG  
**Bronze name:** partner_group_ocrg  
**Total columns in raw:** 3

## Description

Stores the master data of business partner groups (Card Groups in SAP B1). Each row represents a customer or vendor category. It is referenced by OCRD via `GroupCode` to classify each partner.

## Relationships

**Tables that reference OCRG:**
- OCRD via `GroupCode` — group the partner belongs to

## Column mapping

Source of the descriptions: SAP Business One SDK 10.0 — confirmed via `/Business_Partners/OCRG.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| GroupCode | Group No. | group_code | smallint | rename — primary key |
| GroupName | Group Name | group_name | nvarchar | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Registered groups

| GroupCode | GroupName |
|---|---|
| 103 | END CUSTOMER CONSTRUCTION/RENOVATION/ENGINEERING |
| 104 | END CUSTOMER CONSUMER |
| 105 | END CUSTOMER CONTRACTOR |
| 106 | END CUSTOMER RESALE |
| 107 | STORE FRANCHISE |
| 108 | PROJECT FRANCHISE |
| 109 | EMPLOYEE |
| 110 | HOMOLOGATION |
| 111 | INTERCOMPANY |
| 112 | EMPLOYE |
| 113 | MATERIAL FOR CONSUMPTION |
| 114 | MATERIAL FOR RESALE |
| 115 | SERVICE PROVIDER |
| 116 | CARRIER |
| 117 | RECLASSIFY |
| 119 | INTERCOMPANY F |
| 120 | PUBLIC AGENCY |
| 121 | . |
| 123 | CARD |
| 124 | SERVICE PROVDER |

## Database notes

- 20 groups registered
- Groups 109 and 112 are duplicates with different spelling ("EMPLOYEE" and "EMPLOYE") — consider consolidating in silver
- Groups 115 and 124 are duplicates with a typo ("SERVICE PROVIDER" and "SERVICE PROVDER")
- Group 121 with name '.' — junk data, filter out in silver
- Group 117 "RECLASSIFY" indicates partners pending categorization
