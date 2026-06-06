# OINM — Inventory Movement

**SAP table:** OINM (view)
**Bronze name:** inventory_movement_oinm
**Volume cutoff:** `DocDate >= '2025-07-01'` (the full table is too large)
**Total columns in raw:** 13 (+ `_ingestao_em`)

## Description

Inventory movement ledger (Inventory Transactions in SAP B1) — each row is an
inbound (`InQty`) or outbound (`OutQty`) movement of an item in a warehouse, with the value and cost at that moment.
Feeds the balance calculation and the daily inventory movement. It is a **view** in HANA
(materialized in `raw_sap`), with a watermark on `DocDate` and a volume cutoff starting Jul/2025.

## Relationships

- **OITM** (`item_master_oitm`) — moved item, join on `ItemCode`
- **OITW** (`warehouse_stock_oitw`) — stock per warehouse, join on `ItemCode` + `Warehouse`
- `BASE_REF`/`TransType` point to the source document (invoice, transfer, etc.)

## Column mapping

| Raw column | SAP description | Type | Note |
|---|---|---|---|
| TransNum | Transaction Number | int | primary key |
| DocDate | Posting Date | date | ingestion watermark |
| ItemCode | Item No. | nvarchar | moved item |
| Warehouse | Warehouse Code | nvarchar | warehouse |
| InQty | Quantity In | decimal | inbound quantity |
| OutQty | Quantity Out | decimal | outbound quantity |
| TransValue | Transaction Value | decimal | movement value |
| CalcPrice | Calculated Price | decimal | cost calculated at that moment |
| Balance | Cumulative Quantity | decimal | running balance |
| TransType | Document Type | int | object type of the source document |
| CreatedBy | Created By (DocEntry) | int | document that generated the movement |
| BASE_REF | Base Reference | nvarchar | reference to the source document |
| DocLineNum | Document Line Number | int | source document line |
| _ingestao_em | — | datetime2 | ingestion audit column |

## Notes

- Consumed by dbt in `inventory_movements` → `fato_estoque` and `fato_movimentacao_estoque_diaria`.
- As a view, the schema reflects the HANA calculation; the Jul/2025 cutoff applies both as a floor
  and combined with the watermark (see `usp_ing_OINM`).
