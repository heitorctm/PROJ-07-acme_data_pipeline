/* =====================================================================
   00_infra / 03 - meta.ingestion_table
   Control table: what to ingest, from where, how and in which group.
   Populated by the generated seed (01_seed/01_seed_meta_ingestion.sql).
   ===================================================================== */
USE SAP_MIRROR;
GO

IF OBJECT_ID('meta.ingestion_table', 'U') IS NULL
BEGIN
    CREATE TABLE meta.ingestion_table (
        table_name            SYSNAME       NOT NULL CONSTRAINT PK_ingestion_table PRIMARY KEY,
        hana_schema       SYSNAME       NOT NULL,                       -- e.g.: SAP_PROD
        hana_name         SYSNAME       NOT NULL,                       -- name in HANA (with @ when applicable)
        object_type              VARCHAR(10)   NOT NULL CONSTRAINT DF_ing_type  DEFAULT 'table',
        strategy        VARCHAR(40)   NOT NULL CONSTRAINT DF_ing_strategy  DEFAULT 'full_reload',  -- EXECUTED strategy
        source_strategy VARCHAR(40)   NULL,                           -- "natural" strategy from tables.yaml (reference)
        hana_columns      NVARCHAR(MAX) NOT NULL,                       -- "col1", "col2", ...
        sql_columns       NVARCHAR(MAX) NOT NULL,                       -- [col1], [col2], ...
        hana_filter       NVARCHAR(MAX) NULL,                           -- WHERE (without the keyword) or NULL
        load_group       VARCHAR(40)   NOT NULL CONSTRAINT DF_ing_group DEFAULT 'nightly',  -- cadence (hourly/inventory/purchases/nightly) or 'individual'; default = nightly catch-all
        frequency        VARCHAR(20)   NOT NULL CONSTRAINT DF_ing_freq  DEFAULT 'daily',
        sort_order             INT           NOT NULL CONSTRAINT DF_ing_order DEFAULT 1000,
        active             BIT           NOT NULL CONSTRAINT DF_ing_active  DEFAULT 1,
        notes        NVARCHAR(400) NULL,
        _updated_at    DATETIME2     NOT NULL CONSTRAINT DF_ing_updated  DEFAULT SYSDATETIME(),
        CONSTRAINT CK_ing_type  CHECK (object_type IN ('table', 'view'))
        -- load_group without a closed CHECK: cadences are open-ended (see 05_alter_ck_group.sql)
    );
END
GO
