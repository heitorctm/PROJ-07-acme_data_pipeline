/* =====================================================================
   05_monitoring / 02 - audit.vw_issues (table-level)
   Shows, per table, ONLY when the LATEST execution was a problem:
   error, interrupted, or running for more than 60 min (stuck).
   EMPTY view = every table with its latest load OK. Replaces the old
   ad-hoc post-load queries.

   Usage:  SELECT * FROM audit.vw_issues;
   ===================================================================== */
USE SAP_MIRROR;
GO
CREATE OR ALTER VIEW audit.vw_issues AS
WITH latest AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY table_name ORDER BY started_at DESC, id DESC) AS rn
    FROM audit.ingestion_log
)
SELECT
    table_name,
    strategy,
    status,
    CASE
        WHEN status = N'error'         THEN N'error'
        WHEN status = N'interrupted' THEN N'interrupted'
        WHEN status = N'running' AND DATEDIFF(MINUTE, started_at, SYSDATETIME()) > 60 THEN N'stuck'
    END AS diagnosis,
    started_at,
    finished_at,
    DATEDIFF(MINUTE, started_at, ISNULL(finished_at, SYSDATETIME())) AS elapsed_min,
    row_count,
    error_message
FROM latest
WHERE rn = 1
  AND ( status IN (N'error', N'interrupted')
        OR (status = N'running' AND DATEDIFF(MINUTE, started_at, SYSDATETIME()) > 60) );
GO
