# docs_sap — SAP source-table reference

Documentation of the **source tables** in SAP B1 (SAP HANA) that are mirrored into
`raw_sap`: the meaning of each column, relationships, enums, and notes. It serves as a
reference for understanding the source and building the dbt staging.

> **Authority:** the **ingestion strategy and cadence** of each table are defined in
> **`tables.yaml`** (and operationalized in `linked_server/`). The "Strategy/Frequency"
> fields at the top of each doc are informational and may be **out of date** — in case of
> divergence, `tables.yaml` / `linked_server/docs/04_runbook_incremental_cadence.md` prevails.

**Coverage: 51/51 tables** from `tables.yaml`.

## Index by domain

**master_data/** (14) — OCRD, OCRG, OSLP, OBPL, OWHS, OMRC, OPLN, OEXD, OUSG, OUSR, NFN1, @STORES, OHEM, AHEM

**purchases/** (8) — OPCH, PCH1, PCH6, PCH12, OPOR, POR1, OPRQ, PRQ1

**finance/** (5) — OJDT, JDT1, OVPM, OACT, @PROFIT_RANKING

**items/** (7) — OITM, OITW, ITM1, OINM, @ITEM_FAMILY, @ITEM_CLASS, @ITEM_SUB_CLASS

**sales/** (17) — OINV, INV1, INV3, INV6, INV12, OQUT, QUT1, QUT12, ORIN, RIN1, RIN3, RIN12, RIN21, ORDR, RDR1, ODLN, DLN1

## Naming convention

`domain/<bronze_name>_<TABLE>.md` — where `bronze_name` is the name of the dbt staging model
when one exists (e.g., `sales_invoice_OINV.md`). Tables not yet consumed by dbt (OHEM, AHEM,
@PROFIT_RANKING) get a **descriptive** prefix in the file name (e.g., `employee_OHEM.md`,
`employee_log_AHEM.md`, `profit_ranking_PROFIT_RANKING.md`); for those, it is the **`Bronze name:`**
field in the body of the doc that is left as "—".
