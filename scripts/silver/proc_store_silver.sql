-- ====================================================================
-- Project:     Data Warehouse - Silver Ingestion Pipeline (Full Load)
-- Developer:   Yanolitics
-- Purpose:     Cleanse, deduplicate, and transform raw Bronze layer tables.
-- Strategy:    Truncate & Insert (As per design architecture)
-- WARNING:     Truncates all destination tables before importing data.
-- ====================================================================

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
    
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        SET NOCOUNT ON; -- Prevents internal row-count messages from cluttering your custom log

        PRINT '======================================================================';
        PRINT '                    LOADING SILVER LAYER PIPELINE                     ';
        PRINT '======================================================================';
    
        -- ─── SECTION 1: CRM TRANSFORMATIONS ──────────────────────────────────
        PRINT '';
        PRINT '----------------------------------------------------------------------';
        PRINT ' SECTION 1: CRM TRANSFORMATIONS';
        PRINT '----------------------------------------------------------------------';

        -- 1. Load CRM Customer Info
        SET @start_time = GETDATE();
        PRINT '>> Truncating and Transforming: silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;
        
        INSERT INTO silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname)  AS cst_lastname,
            CASE 
                WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                ELSE 'N/A'
            END AS cst_marital_status,
            CASE 
                WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                ELSE 'N/A'
            END AS cst_gndr,
            cst_create_date
        FROM (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL
        ) t
        WHERE flag_last = 1;

        PRINT '>> SUCCESS: silver.crm_cust_info loaded.';
        PRINT '----------------------------------------------------------------------';
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '----------------------------------------------------------------------';

        -- 2. Load CRM Product Info
        SET @start_time = GETDATE();
        PRINT '>> Truncating and Transforming: silver.crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;

        INSERT INTO silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT 
            prd_id,
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
            SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
            TRIM(prd_nm) AS prd_nm,
            COALESCE(prd_cost, 0) AS prd_cost,
            CASE UPPER(TRIM(prd_line))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Touring'
                ELSE 'N/A'
            END AS prd_line,
            CAST(prd_start_dt AS DATE) AS prd_start_dt,
            CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt
        FROM bronze.crm_prd_info;

        PRINT '>> SUCCESS: silver.crm_prd_info loaded.';
        PRINT '----------------------------------------------------------------------';
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '----------------------------------------------------------------------';

        -- 3. Load CRM Sales Details
        SET @start_time = GETDATE();
        PRINT '>> Truncating and Transforming: silver.crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;

        INSERT INTO silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            MAX(clean_order_dt) OVER (PARTITION BY sls_ord_num) AS sls_order_dt,
            MAX(clean_ship_dt)  OVER (PARTITION BY sls_ord_num) AS sls_ship_dt,
            MAX(clean_due_dt)   OVER (PARTITION BY sls_ord_num) AS sls_due_dt,
            corrected_sls_sales AS sls_sales,
            sls_quantity,
            CASE 
                WHEN raw_price IS NULL OR raw_price <= 0 
                THEN corrected_sls_sales / NULLIF(sls_quantity, 0)
                ELSE raw_price
            END AS sls_price
        FROM (
            SELECT
                sls_ord_num, sls_prd_key, sls_cust_id, sls_quantity, sls_price AS raw_price,
                CASE 
                    WHEN TRY_CAST(CAST(NULLIF(sls_order_dt, 0) AS VARCHAR(8)) AS DATE) > '2030-12-31' THEN NULL
                    ELSE TRY_CAST(CAST(NULLIF(sls_order_dt, 0) AS VARCHAR(8)) AS DATE)
                END AS clean_order_dt,
                CASE 
                    WHEN TRY_CAST(CAST(NULLIF(sls_ship_dt, 0)  AS VARCHAR(8)) AS DATE) > '2030-12-31' THEN NULL
                    ELSE TRY_CAST(CAST(NULLIF(sls_ship_dt, 0)  AS VARCHAR(8)) AS DATE)
                END AS clean_ship_dt,
                CASE 
                    WHEN TRY_CAST(CAST(NULLIF(sls_due_dt, 0)   AS VARCHAR(8)) AS DATE) > '2030-12-31' THEN NULL
                    ELSE TRY_CAST(CAST(NULLIF(sls_due_dt, 0)   AS VARCHAR(8)) AS DATE)
                END AS clean_due_dt,
                CASE 
                    WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) 
                    THEN sls_quantity * ABS(sls_price)
                    ELSE sls_sales
                END AS corrected_sls_sales
            FROM bronze.crm_sales_details
        ) AS t;

        PRINT '>> SUCCESS: silver.crm_sales_details loaded.';
        PRINT '----------------------------------------------------------------------';
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '----------------------------------------------------------------------';


        -- ─── SECTION 2: ERP TRANSFORMATIONS ──────────────────────────────────
        PRINT '';
        PRINT '----------------------------------------------------------------------';
        PRINT ' SECTION 2: ERP TRANSFORMATIONS';
        PRINT '----------------------------------------------------------------------';

        -- 4. Load ERP Customer Details
        SET @start_time = GETDATE();
        PRINT '>> Truncating and Transforming: silver.erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;

        INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
        SELECT
            CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) ELSE cid END AS cid,
            CASE WHEN bdate > GETDATE() THEN NULL ELSE bdate END AS bdate,
            CASE
                WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
                WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
                ELSE 'N/A'
            END AS gen
        FROM bronze.erp_cust_az12;

        PRINT '>> SUCCESS: silver.erp_cust_az12 loaded.';
        PRINT '----------------------------------------------------------------------';
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '----------------------------------------------------------------------';

        -- 5. Load ERP Location Mapping
        SET @start_time = GETDATE();
        PRINT '>> Truncating and Transforming: silver.erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;

        INSERT INTO silver.erp_loc_a101 (cid, cntry)
        SELECT
            REPLACE(cid, '-', '') AS cid,
            CASE
                WHEN UPPER(TRIM(cntry)) IN ('DE', 'GERMANY')              THEN 'Germany'
                WHEN UPPER(TRIM(cntry)) IN ('USA', 'US', 'UNITED STATES') THEN 'United States'
                WHEN UPPER(TRIM(cntry)) IN ('UK', 'UNITED KINGDOM')       THEN 'United Kingdom'
                WHEN UPPER(TRIM(cntry)) IN ('AU', 'AUSTRALIA')            THEN 'Australia'
                WHEN UPPER(TRIM(cntry)) IN ('CAN', 'CANADA')              THEN 'Canada'
                WHEN UPPER(TRIM(cntry)) IN ('FR', 'FRANCE')                THEN 'France'
                ELSE 'N/A'
            END AS cntry
        FROM bronze.erp_loc_a101
        WHERE REPLACE(cid, '-', '') IN (SELECT cst_key FROM silver.crm_cust_info);

        PRINT '>> SUCCESS: silver.erp_loc_a101 loaded.';
        PRINT '----------------------------------------------------------------------';
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '----------------------------------------------------------------------';

        -- 6. Load ERP Product Category Matrix
        SET @start_time = GETDATE();
        PRINT '>> Truncating and Transforming: silver.erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        INSERT INTO silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
        SELECT id, cat, subcat, maintenance
        FROM bronze.erp_px_cat_g1v2;

        PRINT '>> SUCCESS: silver.erp_px_cat_g1v2 loaded.';
        PRINT '----------------------------------------------------------------------';
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '----------------------------------------------------------------------';
        
        PRINT '';
        PRINT '';
        PRINT '----------------------------------------------------------------------';
        PRINT 'OVERALL LOAD DURATION';
        SET @batch_end_time = GETDATE();
        PRINT '>> Total Operational Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '----------------------------------------------------------------------';


        -- ─── SECTION 3: QUALITY CHECK & VERIFICATION AUDIT ──────────────────
        PRINT '';
        PRINT '----------------------------------------------------------------------';
        PRINT ' SECTION 3: QUALITY CHECK & VERIFICATION AUDIT';
        PRINT '----------------------------------------------------------------------';
        
        -- Volume Profile Snapshot
        SELECT 'silver.crm_cust_info' AS table_name, COUNT(*) AS total_rows_retained FROM silver.crm_cust_info
        UNION ALL
        SELECT 'silver.crm_prd_info', COUNT(*) FROM silver.crm_prd_info
        UNION ALL
        SELECT 'silver.crm_sales_details', COUNT(*) FROM silver.crm_sales_details
        UNION ALL
        SELECT 'silver.erp_cust_az12', COUNT(*) FROM silver.erp_cust_az12
        UNION ALL
        SELECT 'silver.erp_loc_a101', COUNT(*) FROM silver.erp_loc_a101
        UNION ALL
        SELECT 'silver.erp_px_cat_g1v2', COUNT(*) FROM silver.erp_px_cat_g1v2;

        PRINT '';
        PRINT '>> Reviewing detailed data clean-up assertions...';
        
        -- Diagnostic Error Report Tracking
        SELECT 'crm_cust_info' AS profiling_target, 'Missing Keys/Invalid Flags' AS metrics, 
            SUM(CASE WHEN cst_id IS NULL THEN 1 ELSE 0 END) + SUM(CASE WHEN cst_gndr NOT IN ('Male','Female','N/A') THEN 1 ELSE 0 END) AS issue_count FROM silver.crm_cust_info
        UNION ALL
        SELECT 'crm_prd_info', 'Invalid Date Chronology', SUM(CASE WHEN prd_end_dt < prd_start_dt THEN 1 ELSE 0 END) FROM silver.crm_prd_info
        UNION ALL
        SELECT 'crm_sales_details', 'Broken Financial Calculations', SUM(CASE WHEN sls_sales != sls_quantity * sls_price THEN 1 ELSE 0 END) FROM silver.crm_sales_details
        UNION ALL
        SELECT 'erp_cust_az12', 'Unprocessed "NAS" Prefixes', SUM(CASE WHEN cid LIKE 'NAS%' THEN 1 ELSE 0 END) FROM silver.erp_cust_az12
        UNION ALL
        SELECT 'erp_loc_a101', 'Escaped Key Hyphens', SUM(CASE WHEN cid LIKE '%-%' THEN 1 ELSE 0 END) FROM silver.erp_loc_a101;

        PRINT '';
        PRINT '======================================================================';
        PRINT '               SILVER LAYER LOAD COMPLETED SUCCESSFULLY               ';
        PRINT '======================================================================';
    END TRY
    BEGIN CATCH
        PRINT '======================================================================';
        PRINT '        ERROR OCCURRED DURING LOADING SILVER LAYER PIPELINE           ';
        PRINT '======================================================================';
        PRINT CONCAT('Error Message  : ', ERROR_MESSAGE());
        PRINT CONCAT('Error Number   : ', ERROR_NUMBER());
        PRINT CONCAT('Error Severity : ', ERROR_SEVERITY());
        PRINT CONCAT('Error State    : ', ERROR_STATE());
        PRINT '======================================================================';
    END CATCH
END;
GO
