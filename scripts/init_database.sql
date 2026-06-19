-- ====================================================================
-- Project: Data Warehouse Initialization (Medallion Architecture)
-- Developer: Yanolitics
-- ====================================================================

USE master;
GO

-- Rebuild database if it exists to ensure a clean, reproducible setup
IF EXISTS (SELECT * FROM sys.databases WHERE name = N'DataWarehouse')
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END
GO

CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

-- ─── CREATE MEDALLION SCHEMAS ────────────────────────────────────────

-- Bronze: Raw, untouched source data landing zone
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'bronze') EXEC('CREATE SCHEMA bronze;');
GO

-- Silver: Cleaned, standardized, and normalized data area
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'silver') EXEC('CREATE SCHEMA silver;');
GO

-- Gold: Business-ready dimensional models (Star Schema views)
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'gold') EXEC('CREATE SCHEMA gold;');
GO

-- ─── VERIFICATION ────────────────────────────────────────────────────

SELECT schema_id, name AS schema_name 
FROM sys.schemas 
WHERE name IN ('bronze', 'silver', 'gold');
GO
