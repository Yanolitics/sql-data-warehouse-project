-- ====================================================================
-- Project: Data Warehouse - Bronze Ingestion Pipeline (Full Load)
-- Developer: Yanolitics
-- Purpose: Bulk load raw data from CRM and ERP CSV sources.
-- Strategy: Truncate & Insert (As per design architecture)
-- WARNING: Truncates all destination tables before importing data.
-- ====================================================================

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME,@batch_start_time DATETIME, @batch_end_time DATETIME;
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        SET NOCOUNT ON; -- Prevents internal row-count messages from cluttering your custom log

        PRINT '======================================================================';
        PRINT '                    LOADING BRONZE LAYER PIPELINE                     ';
        PRINT '======================================================================';
    
        -- ─── SECTION 1: CRM INGESTION ───────────────────────────────────────
        PRINT '';
        PRINT '----------------------------------------------------------------------';
        PRINT ' SECTION 1: CRM INGESTION';
        PRINT '----------------------------------------------------------------------';

        -- 1. Ingest CRM Customer Info
        SET @start_time = GETDATE();
        PRINT '>> Truncating and Ingesting: bronze.crm_cust_info';
        TRUNCATE TABLE bronze.crm_cust_info;
        BULK INSERT bronze.crm_cust_info
        FROM 'C:\Users\Timothy\OneDrive\Desktop\LINKEDIN LEARNING DATA ANALYSIS\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '\n',
            FORMAT = 'CSV',
            TABLOCK
        );
        PRINT '>> SUCCESS: bronze.crm_cust_info loaded.';
        PRINT '----------------------------------------------------------------------';
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds';
        PRINT '----------------------------------------------------------------------';

        -- 2. Ingest CRM Product Info
        SET @start_time = GETDATE();
        PRINT '>> Truncating and Ingesting: bronze.crm_prd_info';
        TRUNCATE TABLE bronze.crm_prd_info;
        BULK INSERT bronze.crm_prd_info
        FROM 'C:\Users\Timothy\OneDrive\Desktop\LINKEDIN LEARNING DATA ANALYSIS\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '\n',
            FORMAT = 'CSV',
            TABLOCK
        );
        PRINT '>> SUCCESS: bronze.crm_prd_info loaded.';
        PRINT '----------------------------------------------------------------------';
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds';
        PRINT '----------------------------------------------------------------------';

        -- 3. Ingest CRM Sales Details
        SET @start_time = GETDATE();
        PRINT '>> Truncating and Ingesting: bronze.crm_sales_details';
        TRUNCATE TABLE bronze.crm_sales_details;
        BULK INSERT bronze.crm_sales_details
        FROM 'C:\Users\Timothy\OneDrive\Desktop\LINKEDIN LEARNING DATA ANALYSIS\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '\n',
            FORMAT = 'CSV',
            TABLOCK
        );
        PRINT '>> SUCCESS: bronze.crm_sales_details loaded.';
        PRINT '----------------------------------------------------------------------';
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds';
        PRINT '----------------------------------------------------------------------';


        -- ─── SECTION 2: ERP INGESTION ───────────────────────────────────────
        PRINT '';
        PRINT '----------------------------------------------------------------------';
        PRINT ' SECTION 2: ERP INGESTION';
        PRINT '----------------------------------------------------------------------';

        -- 4. Ingest ERP Customer Guest List
        SET @start_time = GETDATE();
        PRINT '>> Truncating and Ingesting: bronze.erp_cust_az12';
        TRUNCATE TABLE bronze.erp_cust_az12;
        BULK INSERT bronze.erp_cust_az12
        FROM 'C:\Users\Timothy\OneDrive\Desktop\LINKEDIN LEARNING DATA ANALYSIS\sql-data-warehouse-project\datasets\source_erp\CUST_AZ12.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',   
            TABLOCK
        );
        PRINT '>> SUCCESS: bronze.erp_cust_az12 loaded.';
        PRINT '----------------------------------------------------------------------';
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds';
        PRINT '----------------------------------------------------------------------';

        -- 5. Ingest ERP Location Mapping
        SET @start_time = GETDATE();
        PRINT '>> Truncating and Ingesting: bronze.erp_loc_a101';
        TRUNCATE TABLE bronze.erp_loc_a101;
        BULK INSERT bronze.erp_loc_a101
        FROM 'C:\Users\Timothy\OneDrive\Desktop\LINKEDIN LEARNING DATA ANALYSIS\sql-data-warehouse-project\datasets\source_erp\LOC_A101.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '\n',
            FORMAT = 'CSV',
            TABLOCK
        );
        PRINT '>> SUCCESS: bronze.erp_loc_a101 loaded.';
        PRINT '----------------------------------------------------------------------';
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds';
        PRINT '----------------------------------------------------------------------';

        -- 6. Ingest ERP Product Category Matrix
        SET @start_time = GETDATE();
        PRINT '>> Truncating and Ingesting: bronze.erp_px_cat_g1v2';
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;
        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'C:\Users\Timothy\OneDrive\Desktop\LINKEDIN LEARNING DATA ANALYSIS\sql-data-warehouse-project\datasets\source_erp\PX_CAT_G1V2.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '\n',
            FORMAT = 'CSV',
            TABLOCK
        );
        PRINT '>> SUCCESS: bronze.erp_px_cat_g1v2 loaded.';
        PRINT '----------------------------------------------------------------------';
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: '+ CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds';
        PRINT '----------------------------------------------------------------------';
        PRINT ''
        PRINT ''
        PRINT '----------------------------------------------------------------------';
        PRINT 'OVERALL LOAD DURATION'
        SET @batch_end_time = GETDATE();
        PRINT '>> Load Duration: '+ CAST(DATEDIFF(second,@batch_start_time,@batch_end_time) AS NVARCHAR) + 'seconds';
        PRINT '----------------------------------------------------------------------';


        -- ─── SECTION 3: VERIFICATION AUDIT ──────────────────────────────────
        PRINT '';
        PRINT '----------------------------------------------------------------------';
        PRINT ' SECTION 3: VERIFICATION AUDIT';
        PRINT '----------------------------------------------------------------------';
    
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

        PRINT '';
        PRINT '======================================================================';
        PRINT '               BRONZE LAYER LOAD COMPLETED SUCCESSFULLY               ';
        PRINT '======================================================================';
    END TRY
    BEGIN CATCH
        PRINT '======================================================================';
        PRINT '              ERROR OCCURRED DURING LOADING BRONZE LAYER              ';
        PRINT '======================================================================';
        PRINT CONCAT('Error Message  : ', ERROR_MESSAGE());
        PRINT CONCAT('Error Number   : ', ERROR_NUMBER());
        PRINT CONCAT('Error Severity : ', ERROR_SEVERITY());
        PRINT CONCAT('Error State    : ', ERROR_STATE());
        PRINT '======================================================================';
    END CATCH
END;
GO
GO
