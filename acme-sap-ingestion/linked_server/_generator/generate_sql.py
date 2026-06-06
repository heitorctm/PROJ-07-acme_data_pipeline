"""
Data-driven SQL artifact generator for the SAP HANA -> raw_sap ingestion.

It is NOT part of the runtime and does NOT touch any database. It reads
tables.yaml (the source of truth) and (re)writes, inside linked_server/:

  - 01_seed/01_seed_meta_ingestion.sql      -> MERGE of meta.ingestion_table (all tables)
  - 02_procs/dedicated/usp_ing_*.sql       -> dedicated (incremental) procs for the heavy ones
  - 03_jobs/10_jobs_cadence.sql           -> SQL Agent jobs by FREQUENCY (follows the dbt DAGs)

Run it locally whenever tables.yaml changes:

    python linked_server/_generator/generate_sql.py

Architecture (see linked_server/docs/04_runbook_incremental_cadence.md):
  - The ingestion frequency of each table = the frequency of the dbt DAG that consumes it.
  - Heavy tables refreshed intraday use the natural incremental strategy from
    tables.yaml (mirrors the strategies of the previous Python pipeline): incremental_upsert,
    incremental_append, incremental_via_header. They get a DEDICATED PROC.
  - The rest (dims, purchases, orphans) run full_reload via etl.usp_ingest_group
    <frequency>, using the generic proc etl.usp_ingest_table.
  - Families (header+lines) become ONE proc: it captures the header watermark
    BEFORE reloading it (sort_order is critical), upserts the header and loads the
    lines via_header using the pre-captured watermark.
"""
from collections import Counter
from pathlib import Path

import yaml

# --- coordinates (tweak here to switch PROD <-> TEST) -----------------------
SCHEMA_HANA = "SAP_PROD"          # production. Test: SAP_TEST
LINKED = "HANA_LINK"                      # linked server already configured
DB = "SAP_MIRROR"                         # DW database
RAW = "raw_sap"                           # mirror schema

BASE = Path(__file__).resolve().parents[1]   # .../linked_server
YAML = BASE.parent / "tables.yaml"

# --- classification by family / dedicated proc / frequency ------------------
# Document families (header upsert + lines via_header) -> 1 proc each.
FAMILIES = {
    "sales_invoice":     {"header": "OINV", "lines": ["INV1", "INV6", "INV12"]},
    "quote":    {"header": "OQUT", "lines": ["QUT1", "QUT12"]},
    "sales_order": {"header": "ORDR", "lines": ["RDR1"]},
}

# Standalone dedicated procs (incremental strategy comes from tables.yaml).
DEDICATED_STANDALONE = ["OINM", "JDT1", "OJDT"]

# Generic full_reload groups by frequency (run via etl.usp_ingest_group).
# The frequency comes from the dbt DAG that consumes each table.
GROUPS = {
    "hourly":    ["OCRD", "OCRG", "OSLP", "OBPL", "OWHS", "OMRC", "OPLN", "OITM",
                "@ITEM_FAMILY", "@ITEM_SUB_CLASS", "@ITEM_CLASS", "@STORES",
                "OUSG", "OEXD", "OUSR", "ORIN", "RIN1", "RIN12", "RIN3", "INV3"],
    "inventory": ["OITW", "ITM1"],
    "purchases": ["OPCH", "PCH1", "PCH12", "OPOR", "POR1", "OPRQ", "PRQ1"],
    "nightly": ["OACT", "NFN1", "PCH6", "OVPM", "ODLN", "DLN1", "RIN21",
                "OHEM", "AHEM", "@PROFIT_RANKING"],
}

# Date cutoff by volume (on top of the watermark). Today only OINM (>= jul/2025).
FILTERS = {
    "OINM": "\"DocDate\" >= '2025-07-01'",
}

# Job schedules (HHMMSS) -- finish with margin BEFORE the matching DAG. @enabled=0.
# Daily: 1h of margin. Hourly: run at the middle of the hour (:30) -> ~27min before the top-of-hour DAG.
SCHEDULES = {
    "ingestion_hourly":       {"start": "063000", "end": "213000", "subday_h": 1},   # 06:30..21:30 (serves common/sales 07-22h)
    "ingestion_inventory":    {"start": "063000", "end": "213000", "subday_h": 3},   # 06:30,09:30,12:30,15:30,18:30,21:30 (serves inventory 7,10,13,16,19,22h)
    "ingestion_daily_movement": {"start": "040000"},                                    # daily 04:00 (serves daily_movement 5h)
    "ingestion_purchases":    {"start": "050000"},                                    # daily 05:00 (serves purchases_finance 6h)
    "ingestion_nightly":    {"start": "030000"},                                    # daily 03:00 (no scheduled consumer)
}


# --- helpers ----------------------------------------------------------------
def load():
    with YAML.open(encoding="utf-8") as f:
        return yaml.safe_load(f)


def dedup_columns(cfg):
    """Columns in the yaml sort_order, without duplicates (e.g. INV1.Price, OITM.InvntItem)."""
    seen = []
    for c in (cfg.get("columns") or []):
        if c not in seen:
            seen.append(c)
    return seen


def cols_hana(cols):
    return ", ".join(f'"{c}"' for c in cols)


def cols_sql(cols):
    return ", ".join(f"[{c}]" for c in cols)


def lit(s):
    """NVARCHAR literal for the seed; None -> NULL. Escapes single quotes."""
    if s is None:
        return "NULL"
    return "N'" + s.replace("'", "''") + "'"


def freq_of(cfg):
    return (cfg.get("frequency") or "daily").strip()


# --- classification ---------------------------------------------------------
def _family_members():
    m = {}
    for label, fam in FAMILIES.items():
        m[fam["header"]] = label
        for line in fam["lines"]:
            m[line] = label
    return m


FAMILY_MEMBER = _family_members()
DEDICATED = set(FAMILY_MEMBER) | set(DEDICATED_STANDALONE)


def load_group_of(tab):
    """load_group written into meta: 'individual' (dedicated proc) or the frequency."""
    if tab in DEDICATED:
        return "individual"
    for g, tabs in GROUPS.items():
        if tab in tabs:
            return g
    raise SystemExit(f"ERROR: table_name {tab} has no assigned frequency (family/standalone/group).")


def exec_strategy_of(tab, cfg):
    """EXECUTED strategy: incremental for dedicated, full_reload for groups."""
    if tab in DEDICATED:
        return cfg.get("strategy") or "full_reload"
    return "full_reload"


# --- common proc frame ------------------------------------------------------
def proc_wrapper(proc_name, lock_label, try_body):
    return f"""USE {DB};
GO
/* =====================================================================
   etl.{proc_name}  (generated by _generator/generate_sql.py -- do NOT edit by hand)
   Incremental via OPENQUERY({LINKED}). Watermark read from {RAW} itself.
   Frame: applock + audit.ingestion_log + BEGIN TRAN/CATCH (no TRUNCATE).
   ===================================================================== */
CREATE OR ALTER PROCEDURE etl.{proc_name}
    @execution_id UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @execution_id IS NULL SET @execution_id = NEWID();

    DECLARE @row_count INT = 0, @log_id INT = NULL, @msg NVARCHAR(4000),
            @wm_date NVARCHAR(10), @wm_ts INT, @wm_de BIGINT, @cond NVARCHAR(MAX),
            @filtro NVARCHAR(MAX), @rs NVARCHAR(MAX), @q NVARCHAR(MAX);
    DECLARE @lock_res NVARCHAR(255) = N'etl.ingestion.{lock_label}', @lock INT;

    EXEC @lock = sp_getapplock @Resource = @lock_res, @LockMode = 'Exclusive',
                               @LockOwner = 'Session', @LockTimeout = 5000;
    IF @lock < 0 THROW 50002, N'Ingestion already in progress for {lock_label}.', 1;

    BEGIN TRY
{try_body}
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        SET @msg = LEFT(ERROR_MESSAGE(), 4000);
        IF @log_id IS NOT NULL
            UPDATE audit.ingestion_log
                SET finished_at = SYSDATETIME(), status = N'error', error_message = @msg
                WHERE id = @log_id;
        EXEC sp_releaseapplock @Resource = @lock_res, @LockOwner = 'Session';
        THROW;
    END CATCH

    EXEC sp_releaseapplock @Resource = @lock_res, @LockOwner = 'Session';
END
GO
"""


def _log_open(tab, strategy, freq):
    return f"""        -- self-heal: close a previous stuck run of this table_name (the applock guarantees it is dead)
        UPDATE audit.ingestion_log SET status = N'interrupted', finished_at = SYSDATETIME(),
               error_message = N'interrupted: previous run did not finish (closed when starting a new load)'
        WHERE table_name = N'{tab}' AND status = N'running';
        INSERT INTO audit.ingestion_log (execution_id, table_name, strategy, frequency, started_at, status)
        VALUES (@execution_id, N'{tab}', N'{strategy}', N'{freq}', SYSDATETIME(), N'running');
        SET @log_id = SCOPE_IDENTITY();
        SET @row_count = 0;"""


_LOG_CLOSE = """        UPDATE audit.ingestion_log
            SET finished_at = SYSDATETIME(), row_count = @row_count, status = N'success' WHERE id = @log_id;"""


# --- execution blocks (dynamic SQL OPENQUERY) -------------------------------
# In all of them: @filtro must already be set by the caller. #d only lives inside
# the sp_executesql batch, so DELETE/INSERT/@@ROWCOUNT go in the SAME string (@out OUTPUT).
def _exec_upsert(tab, cols, pk_cols):
    join = " AND ".join(f"d.[{c}] = s.[{c}]" for c in pk_cols)
    csql = cols_sql(cols)
    return f"""        SET @rs = N'SELECT {cols_hana(cols)} FROM "{SCHEMA_HANA}"."{tab}"' + @filtro;
        BEGIN TRAN;
            SET @q = N'SELECT * INTO #d FROM OPENQUERY({LINKED}, ''' + REPLACE(@rs, '''', '''''') + N''');'
                   + N' DELETE d FROM {RAW}.[{tab}] d INNER JOIN #d s ON {join};'
                   + N' INSERT INTO {RAW}.[{tab}] ({csql}) SELECT {csql} FROM #d;'
                   + N' SET @out = @@ROWCOUNT;';
            EXEC sp_executesql @q, N'@out INT OUTPUT', @out = @row_count OUTPUT;
        COMMIT;"""


def _exec_viaheader(tab, cols):
    csql = cols_sql(cols)
    return f"""        SET @rs = N'SELECT {cols_hana(cols)} FROM "{SCHEMA_HANA}"."{tab}"' + @filtro;
        BEGIN TRAN;
            SET @q = N'SELECT * INTO #d FROM OPENQUERY({LINKED}, ''' + REPLACE(@rs, '''', '''''') + N''');'
                   + N' DELETE d FROM {RAW}.[{tab}] d INNER JOIN (SELECT DISTINCT [DocEntry] FROM #d) s ON d.[DocEntry] = s.[DocEntry];'
                   + N' INSERT INTO {RAW}.[{tab}] ({csql}) SELECT {csql} FROM #d;'
                   + N' SET @out = @@ROWCOUNT;';
            EXEC sp_executesql @q, N'@out INT OUTPUT', @out = @row_count OUTPUT;
        COMMIT;"""


def _exec_append(tab, cols, wm_col):
    csql = cols_sql(cols)
    return f"""        SET @rs = N'SELECT {cols_hana(cols)} FROM "{SCHEMA_HANA}"."{tab}"' + @filtro;
        BEGIN TRAN;
            IF @wm_date IS NOT NULL
                DELETE FROM {RAW}.[{tab}] WHERE CONVERT(varchar(10), [{wm_col}], 23) = @wm_date;
            SET @q = N'INSERT INTO {RAW}.[{tab}] ({csql}) SELECT {csql} FROM OPENQUERY({LINKED}, ''' + REPLACE(@rs, '''', '''''') + N''');'
                   + N' SET @out = @@ROWCOUNT;';
            EXEC sp_executesql @q, N'@out INT OUTPUT', @out = @row_count OUTPUT;
        COMMIT;"""


# --- procs by strategy ----------------------------------------------------
def proc_family(label, fam, data):
    header = fam["header"]
    header_cfg = data[header]
    header_pk = header_cfg.get("primary_key") or ["DocEntry"]
    parts = []
    # (1) pre-capture the header's composite watermark BEFORE reloading
    parts.append(f"""        -- pre-capture the COMBINED watermark of header {header} (BEFORE reloading) -- sort_order is critical
        -- (UpdateDate, UpdateTS) catch RE-EDITED docs; MAX(DocEntry) catches NEW docs.
        -- DocEntry is SAP's monotonic PK: a new document is born with a higher DocEntry. An
        -- old re-edited doc has a high UpdateTS but a low DocEntry, so it does NOT raise the
        -- DocEntry ceiling -- this avoids poisoning the cutoff and hiding the new invoices
        -- that have a lower UpdateTS.
        SELECT TOP 1 @wm_date = CONVERT(varchar(10), [UpdateDate], 23), @wm_ts = ISNULL([UpdateTS], 0)
        FROM {RAW}.[{header}] WHERE [UpdateDate] IS NOT NULL
        ORDER BY [UpdateDate] DESC, [UpdateTS] DESC;
        SELECT @wm_de = MAX([DocEntry]) FROM {RAW}.[{header}];
        SET @cond = CASE WHEN @wm_date IS NOT NULL
            THEN N'"UpdateDate" > ''' + @wm_date + N''' OR ("UpdateDate" = ''' + @wm_date + N''' AND "UpdateTS" > ' + CAST(@wm_ts AS NVARCHAR(20)) + N') OR "DocEntry" > ' + CAST(ISNULL(@wm_de, 0) AS NVARCHAR(20))
            ELSE NULL END;""")
    # (2) upsert the header
    parts.append(f"""        -- HEADER {header} (incremental_upsert)
        SET @filtro = CASE WHEN @wm_date IS NOT NULL THEN N' WHERE ' + @cond ELSE N'' END;""")
    parts.append(_log_open(header, "incremental_upsert", freq_of(header_cfg)))
    parts.append(_exec_upsert(header, dedup_columns(header_cfg), header_pk))
    parts.append(_LOG_CLOSE)
    # (3) lines via_header using the pre-captured watermark
    for line in fam["lines"]:
        lcfg = data[line]
        parts.append(f"""        -- LINE {line} (incremental_via_header, header {header})
        SET @filtro = CASE WHEN @wm_date IS NOT NULL
            THEN N' WHERE "DocEntry" IN (SELECT "DocEntry" FROM "{SCHEMA_HANA}"."{header}" WHERE ' + @cond + N')'
            ELSE N'' END;""")
        parts.append(_log_open(line, "incremental_via_header", freq_of(lcfg)))
        parts.append(_exec_viaheader(line, dedup_columns(lcfg)))
        parts.append(_LOG_CLOSE)
    return proc_wrapper(f"usp_ing_fam_{label}", f"fam_{label}", "\n".join(parts))


def proc_upsert_standalone(tab, data):
    cfg = data[tab]
    cols = dedup_columns(cfg)
    pk = cfg.get("primary_key") or []
    wm_col = cfg.get("watermark_column")
    wm_ts = cfg.get("watermark_column_ts")
    if wm_ts:
        raise SystemExit(f"ERROR: composite standalone upsert not supported ({tab}); use a family.")
    base = FILTERS.get(tab)
    cap = f"""        SELECT @wm_date = CONVERT(varchar(10), MAX([{wm_col}]), 23) FROM {RAW}.[{tab}];"""
    if base:
        base_esc = base.replace("'", "''")
        filtro = f"""        SET @filtro = N' WHERE {base_esc}'
                    + CASE WHEN @wm_date IS NOT NULL THEN N' AND "{wm_col}" >= ''' + @wm_date + N'''' ELSE N'' END;"""
    else:
        filtro = f"""        SET @filtro = CASE WHEN @wm_date IS NOT NULL THEN N' WHERE "{wm_col}" >= ''' + @wm_date + N'''' ELSE N'' END;"""
    body = "\n".join([cap, filtro, _log_open(tab, "incremental_upsert", freq_of(cfg)),
                       _exec_upsert(tab, cols, pk), _LOG_CLOSE])
    return proc_wrapper(f"usp_ing_{tab}", tab, body)


def proc_append_standalone(tab, data):
    cfg = data[tab]
    cols = dedup_columns(cfg)
    wm_col = cfg.get("watermark_column")
    cap = f"""        SELECT @wm_date = CONVERT(varchar(10), MAX([{wm_col}]), 23) FROM {RAW}.[{tab}];"""
    filtro = f"""        SET @filtro = CASE WHEN @wm_date IS NOT NULL THEN N' WHERE "{wm_col}" >= ''' + @wm_date + N'''' ELSE N'' END;"""
    body = "\n".join([cap, filtro, _log_open(tab, "incremental_append", freq_of(cfg)),
                       _exec_append(tab, cols, wm_col), _LOG_CLOSE])
    return proc_wrapper(f"usp_ing_{tab}", tab, body)


# --- seed -------------------------------------------------------------------
SEED_TEMPLATE = """USE {db};
GO
/* =====================================================================
   Seed of meta.ingestion_table (generated by _generator/generate_sql.py)
   Do NOT edit by hand: run the generator after changing tables.yaml.
   MERGE = inserts new rows and updates existing ones; does not delete orphans.
   strategy = EXECUTED (incremental for dedicated, full_reload for groups).
   load_group = frequency (hourly/inventory/purchases/nightly) or 'individual'.
   ===================================================================== */
SET NOCOUNT ON;

;WITH source (table_name, hana_schema, hana_name, object_type, strategy, source_strategy, hana_columns, sql_columns, hana_filter, load_group, frequency, sort_order) AS (
    SELECT * FROM (VALUES
{values}
    ) v (table_name, hana_schema, hana_name, object_type, strategy, source_strategy, hana_columns, sql_columns, hana_filter, load_group, frequency, sort_order)
)
MERGE meta.ingestion_table AS target
USING source ON target.table_name = source.table_name
WHEN MATCHED THEN UPDATE SET
    hana_schema       = source.hana_schema,
    hana_name         = source.hana_name,
    object_type              = source.object_type,
    strategy        = source.strategy,
    source_strategy = source.source_strategy,
    hana_columns      = source.hana_columns,
    sql_columns       = source.sql_columns,
    hana_filter       = source.hana_filter,
    load_group       = source.load_group,
    frequency        = source.frequency,
    sort_order             = source.sort_order,
    _updated_at    = SYSDATETIME()
WHEN NOT MATCHED BY TARGET THEN
    INSERT (table_name, hana_schema, hana_name, object_type, strategy, source_strategy, hana_columns, sql_columns, hana_filter, load_group, frequency, sort_order)
    VALUES (source.table_name, source.hana_schema, source.hana_name, source.object_type, source.strategy, source.source_strategy, source.hana_columns, source.sql_columns, source.hana_filter, source.load_group, source.frequency, source.sort_order);

PRINT CONCAT('meta.ingestion_table: ', @@ROWCOUNT, ' row(s) affected.');
GO

-- quick check
SELECT load_group, COUNT(*) AS qty
FROM meta.ingestion_table
GROUP BY load_group
ORDER BY load_group;
GO
"""


def build_seed(data):
    rows = []
    for i, (name, cfg) in enumerate(data.items(), 1):
        cols = dedup_columns(cfg)
        filtro = FILTERS.get(name)
        object_type = cfg.get("object_type", "table")
        exec_strat = exec_strategy_of(name, cfg)
        orig_strat = cfg.get("strategy") or "full_reload"
        group = load_group_of(name)
        row = (f"        ({lit(name)}, {lit(SCHEMA_HANA)}, {lit(name)}, {lit(object_type)}, "
                 f"{lit(exec_strat)}, {lit(orig_strat)}, {lit(cols_hana(cols))}, {lit(cols_sql(cols))}, "
                 f"{lit(filtro)}, {lit(group)}, {lit(freq_of(cfg))}, {i})")
        rows.append(row)
    return SEED_TEMPLATE.format(db=DB, values=",\n".join(rows))


# --- dedicated procs --------------------------------------------------------
def build_dedicated(data):
    ded_dir = BASE / "02_procs" / "dedicated"
    ded_dir.mkdir(parents=True, exist_ok=True)
    generated = {}
    for label, fam in FAMILIES.items():
        generated[f"usp_ing_fam_{label}"] = proc_family(label, fam, data)
    for tab in DEDICATED_STANDALONE:
        cfg = data[tab]
        strat = cfg.get("strategy")
        if strat == "incremental_append":
            generated[f"usp_ing_{tab}"] = proc_append_standalone(tab, data)
        elif strat == "incremental_upsert":
            generated[f"usp_ing_{tab}"] = proc_upsert_standalone(tab, data)
        else:
            raise SystemExit(f"ERROR: strategy '{strat}' not supported for standalone dedicated {tab}.")
    for name, text in generated.items():
        (ded_dir / f"{name}.sql").write_text(text, encoding="utf-8")
    # clean up obsolete dedicated procs (e.g. usp_ing_OINV/INV1/OPCH/PCH1 that became family/group)
    removed = []
    for f in ded_dir.glob("usp_ing_*.sql"):
        if f.stem not in generated:
            f.unlink()
            removed.append(f.name)
    return list(generated), removed


# --- jobs by frequency ------------------------------------------------------
JOBS_HEADER = f"""USE msdb;
GO
/* =====================================================================
   SQL Agent jobs by FREQUENCY (generated by generate_sql.py).
   The frequency follows the dbt DAGs. Schedules come DISABLED
   (@enabled = 0 on the schedule) -- enable after validating (see docs/04_runbook...).
   ===================================================================== */
"""

# job -> (description, [(step_name, command)])
JOBS = {
    "ingestion_hourly": (
        "Hourly SAP ingestion (dims + sales) -- follows common/sales (7-22h).",
        [("hourly group (dims + light sales)", "EXEC etl.usp_ingest_group @group = ''hourly'';"),
         ("sales invoice family (OINV+INV1+INV6+INV12)", "EXEC etl.usp_ing_fam_sales_invoice;"),
         ("quote family (OQUT+QUT1+QUT12)", "EXEC etl.usp_ing_fam_quote;"),
         ("sales order family (ORDR+RDR1)", "EXEC etl.usp_ing_fam_sales_order;")],
    ),
    "ingestion_inventory": (
        "SAP inventory ingestion 6x/day -- follows dbt_inventory (7,10,13,16,19,22).",
        [("OINM (incremental_upsert)", "EXEC etl.usp_ing_OINM;"),
         ("inventory group (OITW + ITM1 full)", "EXEC etl.usp_ingest_group @group = ''inventory'';")],
    ),
    "ingestion_daily_movement": (
        "SAP OINM ingestion before the daily close -- follows dbt_daily_movement (5h).",
        [("OINM (incremental_upsert)", "EXEC etl.usp_ing_OINM;")],
    ),
    "ingestion_purchases": (
        "Daily SAP purchases ingestion -- follows dbt_purchases_finance (6h).",
        [("purchases group (full)", "EXEC etl.usp_ingest_group @group = ''purchases'';")],
    ),
    "ingestion_nightly": (
        "Nightly SAP ingestion (no scheduled dbt consumer): ledger, payments, orphans.",
        [("JDT1 (incremental_append)", "EXEC etl.usp_ing_JDT1;"),
         ("OJDT (incremental_append)", "EXEC etl.usp_ing_OJDT;"),
         ("nightly group (full)", "EXEC etl.usp_ingest_group @group = ''nightly'';")],
    ),
}


def _schedule_clause(name):
    h = SCHEDULES[name]
    fields = [f"@job_name = N'{name}'", f"@name = N'sched_{name}'", "@enabled = 0",
              "@freq_type = 4", "@freq_interval = 1"]
    if h.get("subday_h"):
        fields.append("@freq_subday_type = 8")
        fields.append(f"@freq_subday_interval = {h['subday_h']}")
    fields.append(f"@active_start_time = {h['start']}")
    if h.get("end"):
        fields.append(f"@active_end_time = {h['end']}")
    return "EXEC msdb.dbo.sp_add_jobschedule\n     " + ",\n     ".join(fields) + ";"


def _job_sql(name, description, steps):
    out = [f"""
-------------------------------------------------------------------------------
-- Job: {name}
-------------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'{name}')
    EXEC msdb.dbo.sp_delete_job @job_name = N'{name}', @delete_unused_schedule = 1;
GO
EXEC msdb.dbo.sp_add_job @job_name = N'{name}', @enabled = 1, @description = N'{description}';"""]
    n = len(steps)
    for i, (sname, cmd) in enumerate(steps, 1):
        succ = 1 if i == n else 3   # last: quit success; others: go to next
        out.append(f"""EXEC msdb.dbo.sp_add_jobstep
     @job_name = N'{name}', @step_name = N'{sname}',
     @subsystem = N'TSQL', @database_name = N'{DB}', @command = N'{cmd}',
     @on_success_action = {succ}, @on_fail_action = 2, @retry_attempts = 1, @retry_interval = 2;""")
    out.append(_schedule_clause(name))
    out.append(f"EXEC msdb.dbo.sp_add_jobserver @job_name = N'{name}';\nGO")
    return "\n".join(out)


def build_jobs():
    jobs_dir = BASE / "03_jobs"
    jobs_dir.mkdir(parents=True, exist_ok=True)
    body = JOBS_HEADER + "".join(_job_sql(name, desc, steps) for name, (desc, steps) in JOBS.items())
    (jobs_dir / "10_jobs_cadence.sql").write_text(body, encoding="utf-8")
    # clean up old jobs (00_job_bloco.sql, 10_jobs_individuais.sql)
    removed = []
    for f in jobs_dir.glob("*.sql"):
        if f.name != "10_jobs_cadence.sql":
            f.unlink()
            removed.append(f.name)
    return removed


# --- coverage validation ----------------------------------------------------
def validate_coverage(data):
    classified = list(FAMILY_MEMBER) + list(DEDICATED_STANDALONE)
    for tabs in GROUPS.values():
        classified += tabs
    cnt = Counter(classified)
    dups = [t for t, n in cnt.items() if n > 1]
    if dups:
        raise SystemExit(f"ERROR: tables in more than one frequency/group: {dups}")
    missing_in_yaml = [t for t in classified if t not in data]
    if missing_in_yaml:
        raise SystemExit(f"ERROR: classified tables missing from tables.yaml: {missing_in_yaml}")
    unclassified = [t for t in data if t not in cnt]
    if unclassified:
        raise SystemExit(f"ERROR: tables.yaml tables without a frequency: {unclassified}")
    # watermarks required for the dedicated tables
    for tab in DEDICATED:
        cfg, strat = data[tab], data[tab].get("strategy")
        if strat in ("incremental_upsert", "incremental_append") and not cfg.get("watermark_column"):
            raise SystemExit(f"ERROR: {tab} ({strat}) has no watermark_column in tables.yaml.")
        if strat == "incremental_via_header" and not cfg.get("header_table"):
            raise SystemExit(f"ERROR: {tab} (via_header) has no header_table in tables.yaml.")


# --- main -------------------------------------------------------------------
def main():
    data = load()
    validate_coverage(data)

    (BASE / "01_seed").mkdir(parents=True, exist_ok=True)
    (BASE / "01_seed" / "01_seed_meta_ingestion.sql").write_text(build_seed(data), encoding="utf-8")
    procs, ded_removed = build_dedicated(data)
    jobs_removed = build_jobs()

    # ---- check report ----
    print(f"OK. {len(data)} tables in tables.yaml.")
    print(f"  seed   -> 01_seed/01_seed_meta_ingestion.sql")
    print(f"  procs  -> 02_procs/dedicated/  ({len(procs)}): {', '.join(sorted(procs))}")
    if ded_removed:
        print(f"           removed (obsolete): {', '.join(sorted(ded_removed))}")
    print(f"  jobs   -> 03_jobs/10_jobs_cadence.sql  ({len(JOBS)} jobs)")
    if jobs_removed:
        print(f"           removed (obsolete): {', '.join(sorted(jobs_removed))}")

    cnt = Counter(load_group_of(n) for n in data)
    print(f"\nFrequencies/groups: {dict(cnt)}  total={len(data)}")

    print("\nFamilies (header + lines via_header):")
    for label, fam in FAMILIES.items():
        print(f"  usp_ing_fam_{label:13} = {fam['header']} + {', '.join(fam['lines'])}")

    print("\nHANA filters (cutoff by volume):")
    for name, f in FILTERS.items():
        print(f"  {name:16} WHERE {f}")

    print("\nColumn deduplication:")
    any_dups = False
    for name, cfg in data.items():
        orig, ded = cfg.get("columns") or [], dedup_columns(cfg)
        if len(orig) != len(ded):
            any_dups = True
            print(f"  {name}: {len(orig)} -> {len(ded)} (duplicate(s) removed)")
    if not any_dups:
        print("  (none)")


if __name__ == "__main__":
    main()
