/* =====================================================================
   00_infra / 05 - open up load_group for named cadences
   The original CK_ing_group only accepted 'bloco'/'individual'. With cadence-based
   ingestion (hourly/inventory/purchases/nightly + individual) the groups become
   open-ended -- this constraint turns into an obstacle. Drop it.
   Idempotent: only drops if it exists.
   ===================================================================== */
USE SAP_MIRROR;
GO
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_ing_group'
           AND parent_object_id = OBJECT_ID('meta.ingestion_table'))
BEGIN
    ALTER TABLE meta.ingestion_table DROP CONSTRAINT CK_ing_group;
    PRINT 'CK_ing_group dropped: load_group now accepts any cadence.';
END
ELSE
    PRINT 'CK_ing_group no longer exists -- nothing to do.';
GO
