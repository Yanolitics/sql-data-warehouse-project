USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    SET NOCOUNT ON;

    /*
    ===============================================================================
    Procedure Name:      silver.load_silver
    Purpose:             Full data cleansing, transformation, deduplication, 
                         and assertion framework for the Silver architecture.
    Warnings:            This procedure performs FULL REFRESH operations. Running 
                         this will truncate all existing tables in the Silver schema.
    Author:              Timothy
    ===============================================================================
    */

    PRINT '======================================================================';
    PRINT '>> Starting Silver Layer ETL Pipeline Execution...';
    PRINT '======================================================================';

    -- ============================================================================
    -- 1. REFRESH: silver.crm_cust_info
    -- ============================================================================
    PRINT '----------------------------------------------------------------------';
    PRINT '>> Processing Table: silver.crm_cust_info';
    PRINT '----------------------------------------------------------------------';

    PRINT '>> Wiping target table to prepare for fresh data reload...';
    TRUNCATE TABLE silver.crm_cust_info;

    PRINT '>> Deduplicating, transforming, and inserting data...';
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
        
        -- Cleanse string data by removing accidental leading/trailing spaces
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname)  AS cst_lastname,
        
        -- Normalize Marital Status codes into readable dimensions
        CASE 
            WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
            WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
            ELSE 'N/A'
        END AS cst_marital_status,
        
        -- Normalize Gender codes into readable dimensions
        CASE 
            WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
            WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
            ELSE 'N/A'
        END AS cst_gndr,
        
        cst_create_date
    FROM (
        -- Deduplication logic: Tag the most recent record per customer as '1'
        SELECT
            *,
            ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
        FROM bronze.crm_cust_info
        WHERE cst_id IS NOT NULL
    ) t
    WHERE flag_last = 1; 

    PRINT '>> SUCCESS: silver.crm_cust_info loaded.';

    -- Post-Load Data Quality Check
    PRINT '>> Running data quality check for silver.crm_cust_info...';
    SELECT 
        COUNT(*) AS total_rows_checked,
        SUM(CASE WHEN cst_id IS NULL THEN 1 ELSE 0 END) AS count_missing_customer_ids,
        SUM(CASE WHEN cst_key IS NULL OR cst_key = '' THEN 1 ELSE 0 END) AS count_missing_customer_keys,
        SUM(CASE WHEN cst_marital_status NOT IN ('Single', 'Married', 'N/A') THEN 1 ELSE 0 END) AS count_invalid_marital_statuses,
        SUM(CASE WHEN cst_gndr NOT IN ('Male', 'Female', 'N/A') THEN 1 ELSE 0 END) AS count_invalid_gender_formats
    FROM silver.crm_cust_info;


    -- ============================================================================
    -- 2. REFRESH: silver.crm_prd_info
    -- ============================================================================
    PRINT '----------------------------------------------------------------------';
    PRINT '>> Processing Table: silver.crm_prd_info';
    PRINT '----------------------------------------------------------------------';

    PRINT '>> Wiping target table to prepare for fresh data reload...';
    TRUNCATE TABLE silver.crm_prd_info;

    PRINT '>> Transforming and inserting data...';
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
        
        -- Extract and format category ID prefix (e.g., 'BK-M1' -> 'BK_M1')
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
        
        -- Extract internal product key removing the prefix
        SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
        
        -- Cleanse string data by removing accidental leading/trailing spaces
        TRIM(prd_nm) AS prd_nm,
        
        -- Handle missing cost inputs by defaulting to zero
        COALESCE(prd_cost, 0) AS prd_cost,
        
        -- Normalize Product Line codes into descriptive groups
        CASE UPPER(TRIM(prd_line))
            WHEN 'M' THEN 'Mountain'
            WHEN 'R' THEN 'Road'
            WHEN 'S' THEN 'Other Sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'N/A'
        END AS prd_line,
        
        -- Cast raw dates into proper DATE data types
        CAST(prd_start_dt AS DATE) AS prd_start_dt,
        
        -- Calculate timeline expiration date dynamically using historical lead logic
        CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt
    FROM bronze.crm_prd_info;

    PRINT '>> SUCCESS: silver.crm_prd_info loaded.';

    -- Post-Load Data Quality Check
    PRINT '>> Running data quality check for silver.crm_prd_info...';
    SELECT 
        COUNT(*) AS total_rows_checked,
        SUM(CASE WHEN prd_id IS NULL THEN 1 ELSE 0 END) AS count_missing_product_ids,
        SUM(CASE WHEN prd_key IS NULL OR prd_key = '' THEN 1 ELSE 0 END) AS count_missing_product_keys,
        SUM(CASE WHEN prd_line NOT IN ('Mountain', 'Road', 'Other Sales', 'Touring', 'N/A') THEN 1 ELSE 0 END) AS count_invalid_product_lines,
        SUM(CASE WHEN prd_end_dt < prd_start_dt THEN 1 ELSE 0 END) AS count_invalid_chronology_dates
    FROM silver.crm_prd_info;


    -- ============================================================================
    -- 3. REFRESH: silver.crm_sales_details
    -- ============================================================================
    PRINT '----------------------------------------------------------------------';
    PRINT '>> Processing Table: silver.crm_sales_details';
    PRINT '----------------------------------------------------------------------';

    PRINT '>> Wiping target table to prepare for fresh data reload...';
    TRUNCATE TABLE silver.crm_sales_details;

    PRINT '>> Transforming, filtering anomalies, and self-healing data...';
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

        -- FINANCIAL LAYER 2: Calculates unit price using the guaranteed clean sales figure
        CASE 
            WHEN raw_price IS NULL OR raw_price <= 0 
            THEN corrected_sls_sales / NULLIF(sls_quantity, 0)
            ELSE raw_price
        END AS sls_price
    FROM (
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_quantity,
            sls_price AS raw_price,

            -- DATE PROTECTION & SANITY FILTER LAYER
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
            
            -- FINANCIAL LAYER 1: Cleanses total sales first
            CASE 
                WHEN sls_sales IS NULL 
                     OR sls_sales <= 0 
                     OR sls_sales != sls_quantity * ABS(sls_price) 
                THEN sls_quantity * ABS(sls_price)
                ELSE sls_sales
            END AS corrected_sls_sales
        FROM bronze.crm_sales_details
    ) AS t;

    PRINT '>> SUCCESS: silver.crm_sales_details loaded.';

    -- Post-Load Data Quality Check
    PRINT '>> Running data quality check for silver.crm_sales_details...';
    SELECT 
        COUNT(*) AS total_rows_checked,
        SUM(CASE WHEN sls_ord_num IS NULL OR sls_ord_num = '' THEN 1 ELSE 0 END) AS count_missing_order_numbers,
        SUM(CASE WHEN sls_order_dt IS NULL THEN 1 ELSE 0 END) AS count_unhealed_null_dates,
        SUM(CASE WHEN sls_order_dt > '2030-12-31' THEN 1 ELSE 0 END) AS count_rogue_future_dates,
        SUM(CASE WHEN sls_order_dt > sls_ship_dt THEN 1 ELSE 0 END) AS count_order_after_ship_dates,
        SUM(CASE WHEN sls_sales != sls_quantity * sls_price THEN 1 ELSE 0 END) AS count_broken_sales_calculations
    FROM silver.crm_sales_details;


    -- ============================================================================
    -- 4. REFRESH: silver.erp_cust_az12
    -- ============================================================================
    PRINT '----------------------------------------------------------------------';
    PRINT '>> Processing Table: silver.erp_cust_az12';
    PRINT '----------------------------------------------------------------------';

    PRINT '>> Wiping target table to prepare for fresh data reload...';
    TRUNCATE TABLE silver.erp_cust_az12;

    PRINT '>> Transforming and inserting data into silver.erp_cust_az12...';
    INSERT INTO silver.erp_cust_az12 (
        cid,
        bdate,
        gen
    )
    SELECT
        -- 1. CLEAN ID: Strip 'NAS' prefix if present
        CASE 
            WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
            ELSE cid
        END AS cid,

        -- 2. CLEAN BIRTHDATE: Set rogue future dates to NULL
        CASE 
            WHEN bdate > GETDATE() THEN NULL
            ELSE bdate
        END AS bdate,

        -- 3. STANDARDIZE GENDER: Unified to 'Male', 'Female', or 'N/A'
        CASE
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
            ELSE 'N/A'
        END AS gen
    FROM bronze.erp_cust_az12;

    PRINT '>> Silver layer refresh for erp_cust_az12 complete!';

    -- Post-Load Data Quality Check
    PRINT '>> Running data quality check for silver.erp_cust_az12...';
    SELECT 
        COUNT(*) AS total_rows_checked,
        SUM(CASE WHEN cid IS NULL OR cid = '' THEN 1 ELSE 0 END) AS count_missing_customer_ids,
        SUM(CASE WHEN cid LIKE 'NAS%' THEN 1 ELSE 0 END) AS count_escaped_nas_prefixes,
        SUM(CASE WHEN bdate > GETDATE() THEN 1 ELSE 0 END) AS count_invalid_future_birthdates,
        SUM(CASE WHEN gen NOT IN ('Male', 'Female', 'N/A') THEN 1 ELSE 0 END) AS count_invalid_gender_formats
    FROM silver.erp_cust_az12;


    -- ============================================================================
    -- 5. REFRESH: silver.erp_loc_a101
    -- ============================================================================
    PRINT '----------------------------------------------------------------------';
    PRINT '>> Processing Table: silver.erp_loc_a101';
    PRINT '----------------------------------------------------------------------';

    PRINT '>> Wiping target table to prepare for fresh data reload...';
    TRUNCATE TABLE silver.erp_loc_a101;

    PRINT '>> Transforming and inserting data into silver.erp_loc_a101...';
    INSERT INTO silver.erp_loc_a101 (
        cid,
        cntry
    )
    SELECT
        -- 1. CLEAN ID: Remove all hyphens from customer IDs
        REPLACE(cid, '-', '') AS cid,

        -- 2. STANDARDIZE COUNTRY: Unified to full country names or 'N/A'
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
    WHERE REPLACE(cid, '-', '') IN (
        SELECT cst_key 
        FROM silver.crm_cust_info
    );

    PRINT '>> Silver layer refresh for erp_loc_a101 complete!';

    -- Post-Load Data Quality Check
    PRINT '>> Running data quality check for silver.erp_loc_a101...';
    SELECT 
        COUNT(*) AS total_rows_checked,
        SUM(CASE WHEN cid IS NULL OR cid = '' THEN 1 ELSE 0 END) AS count_missing_customer_ids,
        SUM(CASE WHEN cid LIKE '%-%' THEN 1 ELSE 0 END) AS count_escaped_hyphens,
        SUM(CASE WHEN cntry NOT IN ('Germany', 'United States', 'United Kingdom', 'Australia', 'Canada', 'France', 'N/A') THEN 1 ELSE 0 END) AS count_invalid_country_formats
    FROM silver.erp_loc_a101;


    -- ============================================================================
    -- 6. REFRESH: silver.erp_px_cat_g1v2
    -- ============================================================================
    PRINT '----------------------------------------------------------------------';
    PRINT '>> Processing Table: silver.erp_px_cat_g1v2';
    PRINT '----------------------------------------------------------------------';

    PRINT '>> Wiping target table to prepare for fresh data reload...';
    TRUNCATE TABLE silver.erp_px_cat_g1v2;

    PRINT '>> Transforming and inserting data into silver.erp_px_cat_g1v2...';
    INSERT INTO silver.erp_px_cat_g1v2 (
        id,
        cat,
        subcat,
        maintenance
    )
    SELECT
        -- 1. ID: Category Identifier
        id,

        -- 2. CATEGORY: Core product classification
        cat,

        -- 3. SUBCATEGORY: Detailed sub-classification
        subcat,

        -- 4. MAINTENANCE: Operational flag or status description
        maintenance
    FROM bronze.erp_px_cat_g1v2;

    PRINT '>> Silver layer refresh for erp_px_cat_g1v2 complete!';

    -- Post-Load Data Quality Check
    PRINT '>> Running data quality check for silver.erp_px_cat_g1v2...';
    SELECT 
        COUNT(*) AS total_rows_checked,
        SUM(CASE WHEN id IS NULL OR id = '' THEN 1 ELSE 0 END) AS count_missing_ids,
        SUM(CASE WHEN cat IS NULL OR cat = '' THEN 1 ELSE 0 END) AS count_missing_categories,
        SUM(CASE WHEN subcat IS NULL OR subcat = '' THEN 1 ELSE 0 END) AS count_missing_subcategories
    FROM silver.erp_px_cat_g1v2;

    PRINT '======================================================================';
    PRINT '>> Master Silver Layer ETL Pipeline Execution Complete.';
    PRINT '======================================================================';
END;
GO
