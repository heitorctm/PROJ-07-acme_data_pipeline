/* =====================================================================
   04_validation / 02 - test of ALL ingestion procs/groups
   Covers the 51 tables: 12 dedicated (incremental) + 4 full_reload groups.
   ROUND 1 runs everything and shows the result; ROUND 2 re-runs only the
   incrementals and proves idempotency (stable count + PK with no duplicates).
   CROSSES THE PRODUCTION HANA -- run OUTSIDE business hours.
   What to check:
     (1) all status = 'success'; real strategy (not 'full_reload' on the dedicated ones)
     (2) row_count of the incrementals = small DELTA (not the whole table)
     (3) ROUND 2: delta between rounds = 0 and dups = 0
   ===================================================================== */
USE SAP_MIRROR;
SET NOCOUNT ON;
GO

------------------------------------------------------------------------
-- ROUND 1 -- runs everything (dedicated procs + groups)
------------------------------------------------------------------------
DECLARE @t0 DATETIME2 = SYSDATETIME();
DECLARE @e  UNIQUEIDENTIFIER = NEWID();

PRINT '=== ROUND 1 / dedicated (incremental) ===';
EXEC etl.usp_ing_fam_sales_invoice     @execution_id = @e;   -- OINV + INV1 + INV6 + INV12
EXEC etl.usp_ing_fam_quote    @execution_id = @e;   -- OQUT + QUT1 + QUT12
EXEC etl.usp_ing_fam_sales_order @execution_id = @e;   -- ORDR + RDR1
EXEC etl.usp_ing_OINM             @execution_id = @e;   -- upsert (DocDate)
EXEC etl.usp_ing_JDT1             @execution_id = @e;   -- append (RefDate)
EXEC etl.usp_ing_OJDT             @execution_id = @e;   -- append (RefDate)

PRINT '=== ROUND 1 / groups (full_reload) ===';
EXEC etl.usp_ingest_group @group = 'hourly';      -- 20 tables (dims + light sales)
EXEC etl.usp_ingest_group @group = 'inventory';   -- OITW, ITM1
EXEC etl.usp_ingest_group @group = 'purchases';   -- 7 tables
EXEC etl.usp_ingest_group @group = 'nightly';   -- 10 tables

-- (1)+(2) detail per table (time window: catches procs + groups)
SELECT table_name, strategy, status, row_count,
       DATEDIFF(SECOND, started_at, finished_at) AS sec, started_at
FROM audit.ingestion_log
WHERE started_at >= @t0
ORDER BY started_at;

-- round summary
SELECT COUNT(*) AS tables,
       SUM(CASE WHEN status = 'success'      THEN 1 ELSE 0 END) AS success,
       SUM(CASE WHEN status = 'error'         THEN 1 ELSE 0 END) AS error,
       SUM(CASE WHEN status = 'running' THEN 1 ELSE 0 END) AS running,
       SUM(row_count) AS total_rows,
       DATEDIFF(SECOND, MIN(started_at), MAX(ISNULL(finished_at, SYSDATETIME()))) AS total_sec
FROM audit.ingestion_log
WHERE started_at >= @t0;

-- snapshot of the 12 incrementals to compare in round 2
IF OBJECT_ID('tempdb..#snap1') IS NOT NULL DROP TABLE #snap1;
SELECT table_name, n INTO #snap1 FROM (
              SELECT 'OINV'  AS table_name, COUNT(*) AS n FROM raw_sap.OINV
    UNION ALL SELECT 'INV1',  COUNT(*) FROM raw_sap.INV1
    UNION ALL SELECT 'INV6',  COUNT(*) FROM raw_sap.INV6
    UNION ALL SELECT 'INV12', COUNT(*) FROM raw_sap.INV12
    UNION ALL SELECT 'OQUT',  COUNT(*) FROM raw_sap.OQUT
    UNION ALL SELECT 'QUT1',  COUNT(*) FROM raw_sap.QUT1
    UNION ALL SELECT 'QUT12', COUNT(*) FROM raw_sap.QUT12
    UNION ALL SELECT 'ORDR',  COUNT(*) FROM raw_sap.ORDR
    UNION ALL SELECT 'RDR1',  COUNT(*) FROM raw_sap.RDR1
    UNION ALL SELECT 'OINM',  COUNT(*) FROM raw_sap.OINM
    UNION ALL SELECT 'JDT1',  COUNT(*) FROM raw_sap.JDT1
    UNION ALL SELECT 'OJDT',  COUNT(*) FROM raw_sap.OJDT
) x;
GO

------------------------------------------------------------------------
-- ROUND 2 -- re-runs ONLY the incrementals and compares (idempotency)
--   full_reload is idempotent by construction; what we need to prove is
--   that the incremental does NOT DUPLICATE when run again.
------------------------------------------------------------------------
DECLARE @t1 DATETIME2 = SYSDATETIME();
DECLARE @e2 UNIQUEIDENTIFIER = NEWID();
EXEC etl.usp_ing_fam_sales_invoice     @execution_id = @e2;
EXEC etl.usp_ing_fam_quote    @execution_id = @e2;
EXEC etl.usp_ing_fam_sales_order @execution_id = @e2;
EXEC etl.usp_ing_OINM             @execution_id = @e2;
EXEC etl.usp_ing_JDT1             @execution_id = @e2;
EXEC etl.usp_ing_OJDT             @execution_id = @e2;

-- (3a) round1 count vs round2 -- delta should be ~0
SELECT s.table_name, s.n AS after_round1, c.n AS after_round2, c.n - s.n AS delta
FROM #snap1 s
JOIN (
              SELECT 'OINV'  AS table_name, COUNT(*) AS n FROM raw_sap.OINV
    UNION ALL SELECT 'INV1',  COUNT(*) FROM raw_sap.INV1
    UNION ALL SELECT 'INV6',  COUNT(*) FROM raw_sap.INV6
    UNION ALL SELECT 'INV12', COUNT(*) FROM raw_sap.INV12
    UNION ALL SELECT 'OQUT',  COUNT(*) FROM raw_sap.OQUT
    UNION ALL SELECT 'QUT1',  COUNT(*) FROM raw_sap.QUT1
    UNION ALL SELECT 'QUT12', COUNT(*) FROM raw_sap.QUT12
    UNION ALL SELECT 'ORDR',  COUNT(*) FROM raw_sap.ORDR
    UNION ALL SELECT 'RDR1',  COUNT(*) FROM raw_sap.RDR1
    UNION ALL SELECT 'OINM',  COUNT(*) FROM raw_sap.OINM
    UNION ALL SELECT 'JDT1',  COUNT(*) FROM raw_sap.JDT1
    UNION ALL SELECT 'OJDT',  COUNT(*) FROM raw_sap.OJDT
) c ON c.table_name = s.table_name
ORDER BY ABS(c.n - s.n) DESC;

-- (3b) duplicate PK -- should all be 0
SELECT 'OINV'  AS table_name, COUNT(*) AS dups FROM (SELECT DocEntry FROM raw_sap.OINV GROUP BY DocEntry HAVING COUNT(*) > 1) x
UNION ALL SELECT 'INV1',  COUNT(*) FROM (SELECT DocEntry, LineNum FROM raw_sap.INV1 GROUP BY DocEntry, LineNum HAVING COUNT(*) > 1) x
UNION ALL SELECT 'INV6',  COUNT(*) FROM (SELECT DocEntry, InstlmntID FROM raw_sap.INV6 GROUP BY DocEntry, InstlmntID HAVING COUNT(*) > 1) x
UNION ALL SELECT 'INV12', COUNT(*) FROM (SELECT DocEntry FROM raw_sap.INV12 GROUP BY DocEntry HAVING COUNT(*) > 1) x
UNION ALL SELECT 'OQUT',  COUNT(*) FROM (SELECT DocEntry FROM raw_sap.OQUT GROUP BY DocEntry HAVING COUNT(*) > 1) x
UNION ALL SELECT 'QUT1',  COUNT(*) FROM (SELECT DocEntry, LineNum FROM raw_sap.QUT1 GROUP BY DocEntry, LineNum HAVING COUNT(*) > 1) x
UNION ALL SELECT 'QUT12', COUNT(*) FROM (SELECT DocEntry FROM raw_sap.QUT12 GROUP BY DocEntry HAVING COUNT(*) > 1) x
UNION ALL SELECT 'ORDR',  COUNT(*) FROM (SELECT DocEntry FROM raw_sap.ORDR GROUP BY DocEntry HAVING COUNT(*) > 1) x
UNION ALL SELECT 'RDR1',  COUNT(*) FROM (SELECT DocEntry, LineNum FROM raw_sap.RDR1 GROUP BY DocEntry, LineNum HAVING COUNT(*) > 1) x
UNION ALL SELECT 'OINM',  COUNT(*) FROM (SELECT TransNum FROM raw_sap.OINM GROUP BY TransNum HAVING COUNT(*) > 1) x
UNION ALL SELECT 'JDT1',  COUNT(*) FROM (SELECT TransId, Line_ID FROM raw_sap.JDT1 GROUP BY TransId, Line_ID HAVING COUNT(*) > 1) x
UNION ALL SELECT 'OJDT',  COUNT(*) FROM (SELECT TransId FROM raw_sap.OJDT GROUP BY TransId HAVING COUNT(*) > 1) x
ORDER BY dups DESC;

-- round 2 log
SELECT table_name, strategy, status, row_count, DATEDIFF(SECOND, started_at, finished_at) AS sec
FROM audit.ingestion_log
WHERE started_at >= @t1
ORDER BY started_at;
GO
