-- ====================================================================
-- Project: Data Warehouse - Bronze Ingestion Pipeline (Full Load)
-- Developer: Yanolitics
-- Purpose: Bulk load raw data from CRM and ERP CSV sources.
-- Strategy: Truncate & Insert (As per design architecture)
-- WARNING: Truncates all destination tables before importing data.
-- ====================================================================

USE DataWarehouse;
GO

-- ─── SECTION 1: CRM INGESTION ───────────────────────────────────────

-- 1. Ingest CRM Customer Info
TRUNCATE TABLE bronze.crm_cust_info;
GO
BULK INSERT bronze.crm_cust_info
FROM 'C:\Users\Timothy\OneDrive\Desktop\LINKEDIN LEARNING DATA ANALYSIS\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FORMAT = 'CSV',
    TABLOCK
);
GO

-- 2. Ingest CRM Product Info
TRUNCATE TABLE bronze.crm_prd_info;
GO
BULK INSERT bronze.crm_prd_info
FROM 'C:\Users\Timothy\OneDrive\Desktop\LINKEDIN LEARNING DATA ANALYSIS\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FORMAT = 'CSV',
    TABLOCK
);
GO

-- 3. Ingest CRM Sales Details
TRUNCATE TABLE bronze.crm_sales_details;
GO
BULK INSERT bronze.crm_sales_details
FROM 'C:\Users\Timothy\OneDrive\Desktop\LINKEDIN LEARNING DATA ANALYSIS\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FORMAT = 'CSV',
    TABLOCK
);
GO


-- ─── SECTION 2: ERP INGESTION ───────────────────────────────────────

-- 4. Ingest ERP Customer Guest List
TRUNCATE TABLE bronze.erp_cust_az12;
GO

BULK INSERT bronze.erp_cust_az12
FROM 'C:\Users\Timothy\OneDrive\Desktop\LINKEDIN LEARNING DATA ANALYSIS\sql-data-warehouse-project\datasets\source_erp\CUST_AZ12.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',   
    TABLOCK
);
GO

-- 5. Ingest ERP Location Mapping
TRUNCATE TABLE bronze.erp_loc_a101;
GO
BULK INSERT bronze.erp_loc_a101
FROM 'C:\Users\Timothy\OneDrive\Desktop\LINKEDIN LEARNING DATA ANALYSIS\sql-data-warehouse-project\datasets\source_erp\LOC_A101.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FORMAT = 'CSV',
    TABLOCK
);
GO

-- 6. Ingest ERP Product Category Matrix
TRUNCATE TABLE bronze.erp_px_cat_g1v2;
GO
BULK INSERT bronze.erp_px_cat_g1v2
FROM 'C:\Users\Timothy\OneDrive\Desktop\LINKEDIN LEARNING DATA ANALYSIS\sql-data-warehouse-project\datasets\source_erp\PX_CAT_G1V2.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FORMAT = 'CSV',
    TABLOCK
);
GO


-- ─── SECTION 3: VERIFICATION AUDIT ──────────────────────────────────

SELECT 'bronze.crm_cust_info' AS table_name, COUNT(*) AS total_rows_loaded FROM bronze.crm_cust_info
UNION ALL
SELECT 'bronze.crm_prd_info', COUNT(*) FROM bronze.crm_prd_info
UNION ALL
SELECT 'bronze.crm_sales_details', COUNT(*) FROM bronze.crm_sales_details
UNION ALL
SELECT 'bronze.erp_cust_az12', COUNT(*) FROM bronze.erp_cust_az12
UNION ALL
SELECT 'bronze.erp_loc_a101', COUNT(*) FROM bronze.erp_loc_a101
UNION ALL
SELECT 'bronze.erp_px_cat_g1v2', COUNT(*) FROM bronze.erp_px_cat_g1v2;
GO
