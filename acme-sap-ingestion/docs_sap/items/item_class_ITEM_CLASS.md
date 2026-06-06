# @ITEM_CLASS — Item Class

**SAP table:** @ITEM_CLASS  
**Bronze name:** item_class  
**Total columns in raw:** 3

## Description

Custom table (User-Defined Table in SAP B1) that stores Acme's product class registry. It is the second level of the item classification hierarchy: Family → Class → Subclass. The `U_CLASS` field of OITM references the `Code` of this table.

Not documented in the SAP SDK — table created by Acme.

## Relationships

**Tables that reference @ITEM_CLASS:**
- OITM via `U_CLASS` — each item belongs to a class

## Column mapping

Source: raw database (no SDK — custom table).

| Raw column | Bronze name | Bronze type | Transformation |
|---|---|---|---|
| Code | class_code | nvarchar | rename — primary key |
| Name | class_name | nvarchar | rename |
| _ingestao_em | _ingestao_em | datetime2 | rename — ingestion audit column |

## Registered classes

| Code | Name |
|---|---|
| 01 | 1.1. BOARDS |
| 02 | 1.2. PROFILE |
| 03 | 1.3. FINISHES |
| 04 | 1.4. FASTENING |
| 05 | 1.5. ACCESSORIES |
| 06 | 2.1. PROFILE |
| 07 | 2.2. BOARD |
| 08 | 2.3. FINISH |
| 09 | 2.4. COMPLEMENTS |
| 10 | 2.5. TRUSS |
| 11 | 2.6. ROOF TRUSSES |
| 12 | 3.1. INSULATION WOOL |
| 13 | 3.2. WOOD CLADDING |
| 14 | 3.3. FOAMS |
| 15 | 3.4. ACOUSTIC CLADDING |
| 16 | 4.1. VINYL |
| 17 | 2.7. FLOORS AND SLABS |
| 18 | 5.1. MORTAR |
| 19 | 5.2. GROUTS |
| 20 | 5.3. WATERPROOFING |
| 21 | 5.4. VINYL INSTALLATION |
| 22 | 5.5. CEMENTS |
| 23 | 6.1. METAL ROOF TILES |
| 24 | 6.2. FIBER CEMENT SHEETS |
| 25 | 6.3. SHINGLE ROOF TILES |
| 26 | 7.1. PRE-HUNG DOOR |
| 27 | 7.2. PVC WINDOWS AND DOORS |
| 28 | 8.1. MINERAL |
| 29 | 8.2. GLASS WOOL |
| 30 | 8.3. PVC |
| 31 | 8.4. EPS / STYROFOAM |
| 32 | 8.5. WOOD |
| 33 | 8.6. GYPSUM |
| 34 | 9.1. HAND TOOL |
| 35 | 9.2. POWER TOOL |

## Database notes

- 36 records total; 35 valid classes + 1 junk record (code 36, Name='.')
- Recommendation: filter `class_code != '36'` when building the silver layer
- The numbering in the name reflects the hierarchy: the prefix indicates the parent family (e.g., '1.1.' belongs to family '01 - DRYWALL')
