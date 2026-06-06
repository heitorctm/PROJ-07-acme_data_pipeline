# @PROFIT_RANKING — Profit Ranking by Store (custom UDT)

**SAP table:** @PROFIT_RANKING (User-Defined Table)
**Bronze name:** — (not yet consumed by dbt)
**Total raw columns:** 3 (+ `_ingestao_em`)

## Description

**Acme custom table** (UDT — `@` prefix, `U_` fields), not part of standard SAP.
Holds a profit value per store and date — used for ranking/tracking results by
store. Being small, it is fully reloaded every day (`full_reload`).

## Column mapping

| Raw column | Description | Type | Note |
|---|---|---|---|
| U_Store | Store | nvarchar(50) | key (part 1) — store identifier |
| U_Date | Date | datetime2 | key (part 2) — reference date |
| U_Profit | Profit | nvarchar(10) | **stored as text** — convert to numeric downstream |
| _ingestao_em | — | datetime2 | ingestion audit column |

## Notes

- Key: `U_Store` + `U_Date`.
- ⚠️ `U_Profit` is `NVARCHAR(10)` in raw (text) — any calculation requires `CAST`/`TRY_CONVERT`
  and attention to the decimal separator. It is a faithful mirror of the UDT in SAP.
- Custom table; no reference in the SAP SDK. No dbt model consumes it yet.
