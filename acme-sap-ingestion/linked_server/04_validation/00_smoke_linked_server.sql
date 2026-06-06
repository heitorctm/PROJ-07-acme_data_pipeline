/* =====================================================================
   04_validation / 00 - SMOKE TEST of the HANA_LINK linked server

   WARNING: EVERY query below CROSSES the linked server and hits the
   PRODUCTION SAP HANA. Run ONE AT A TIME, during off-peak hours, from
   test 0 to 5, only moving on if the previous one came back quickly. DO NOT
   run the whole file at once. If a query hangs, use KILL <session_id>
   (see the end).

   Goal: prove connectivity and push-down BEFORE touching the loads.
   ===================================================================== */
USE SAP_MIRROR;
GO

-------------------------------------------------------------------------------
-- TEST 0  | pure connectivity (cost ~ zero)
-------------------------------------------------------------------------------
SELECT * FROM OPENQUERY(HANA_LINK, 'SELECT 1 AS ok FROM DUMMY');
GO

-------------------------------------------------------------------------------
-- TEST 1  | read a small table (few rows, low cost)
-------------------------------------------------------------------------------
SELECT TOP 5 * FROM OPENQUERY(HANA_LINK,
    'SELECT "Code", "Name" FROM "SAP_PROD"."@STORES"');
GO

-------------------------------------------------------------------------------
-- TEST 2  | COUNT of a small table (validates remote aggregation, low cost)
-------------------------------------------------------------------------------
SELECT * FROM OPENQUERY(HANA_LINK,
    'SELECT COUNT(*) AS n FROM "SAP_PROD"."@STORES"');
GO

-------------------------------------------------------------------------------
-- TEST 3  | sizes the full reload VOLUME (COUNT, without pulling data).
--           OINV/JDT1 come WHOLE (no filter); OINM comes with the real cutoff.
--           Use these numbers to estimate time and decide whether any table
--           besides OINM also needs a cutoff.
-------------------------------------------------------------------------------
SELECT * FROM OPENQUERY(HANA_LINK,
    'SELECT COUNT(*) AS n FROM "SAP_PROD"."OINV"');
GO
SELECT * FROM OPENQUERY(HANA_LINK,
    'SELECT COUNT(*) AS n FROM "SAP_PROD"."JDT1"');
GO
SELECT * FROM OPENQUERY(HANA_LINK,
    'SELECT COUNT(*) AS n FROM "SAP_PROD"."OINM" WHERE "DocDate" >= ''2025-07-01''');
GO

-------------------------------------------------------------------------------
-- TEST 4  | real sample of columns from a heavy table (low cost: TOP 10)
-------------------------------------------------------------------------------
SELECT * FROM OPENQUERY(HANA_LINK,
    'SELECT TOP 10 "DocEntry", "DocNum", "DocDate", "UpdateDate", "DocTotal"
     FROM "SAP_PROD"."OINV"');
GO

-------------------------------------------------------------------------------
-- TEST 5  | REAL end-to-end load of a small table (touches raw_sap)
--           Prerequisite: infra + seed + generic proc already applied.
--           Measures the full TRUNCATE+INSERT+log path on something cheap.
-------------------------------------------------------------------------------
-- EXEC etl.usp_ingest_table @table_name = '@STORES';
-- SELECT TOP 5 * FROM raw_sap.[@STORES];
-- SELECT TOP 1 * FROM audit.ingestion_log WHERE table_name = '@STORES' ORDER BY id DESC;
GO

-------------------------------------------------------------------------------
-- HELP | if a query hangs, identify and kill the session:
-------------------------------------------------------------------------------
-- SELECT session_id, status, command, wait_type, start_time, text
-- FROM sys.dm_exec_requests CROSS APPLY sys.dm_exec_sql_text(sql_handle)
-- WHERE session_id <> @@SPID;
-- KILL <session_id>;   -- undoes the session's transaction; the ROLLBACK is automatic
GO
