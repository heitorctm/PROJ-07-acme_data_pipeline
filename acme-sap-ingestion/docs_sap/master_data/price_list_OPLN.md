# OPLN — Price List

**SAP table:** OPLN  
**Bronze name:** price_list_opln  
**Total columns in raw:** 3

## Description

Stores the master data of price lists (Price Lists in SAP B1). Each row represents a named price list. It is referenced by ITM1 via `PriceList`/`ListNum`, which stores the price of each item in each list.

The lists follow a naming convention that encodes state, customer type and payment terms — for example: `ST1_CLIFIN_MEGASTORE_CASH` = State 1, end customer (CLIFIN), Mega Store, cash payment.

## Relationships

**Tables that reference OPLN:**
- ITM1 via `PriceList` — item price per list

## Column mapping

Source of the descriptions: SAP Business One SDK 10.0 — confirmed via `/Inventory_and_Production/OPLN.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| ListNum | Price List No. | price_list_number | smallint | rename — primary key |
| ListName | Price List Name | price_list_name | nvarchar | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 194 price lists registered
- List naming convention: `{STATE}_{CUSTOMER_TYPE}_{CHANNEL}_{PAYMENT}`
  - STATE: ST1, ST2, ST3, ST4, ST5, ST6
  - Customer type: FRANQ (franchise), CLIFIN (end customer)
  - Channel: MEGASTORE, SUPPLY, FACTORY_A, FACTORY_B, FACTORY_C
  - Payment: CASH, DEBIT, CARD_CASH, CARD_6X, CARD_12X, INV_28D, INV_28/42/56D
- Lists 1–6 are base cost lists per state and franchisor sales (no naming convention)
- Full list available via `SELECT ListNum, ListName FROM raw_sap.OPLN ORDER BY ListNum`
