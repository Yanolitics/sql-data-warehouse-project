/*
===============================================================================
Script Name:         Load & Validate Silver Layer - erp_cust_az12
Purpose:             1. Cleanses and loads customer data from Bronze to Silver.
                     2. Runs a simple post-load quality check for anomalies.
Warnings:            This is a full refresh script. Running this will wipe 
                     all existing data in silver.erp_cust_az12.
Author:              Timothy
===============================================================================
*/

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


-- ============================================================================
-- POST-LOAD DATA QUALITY CHECK
-- ============================================================================
PRINT '>> Running post-load data quality check...';

SELECT 
    COUNT(*) AS total_rows_checked,
    
    -- 1. Check for blank or missing IDs
    SUM(CASE WHEN cid IS NULL OR cid = '' THEN 1 ELSE 0 END) AS count_missing_customer_ids,
    
    -- 2. Check if any 'NAS' prefixes managed to sneak through
    SUM(CASE WHEN cid LIKE 'NAS%' THEN 1 ELSE 0 END) AS count_escaped_nas_prefixes,
    
    -- 3. Check for any unhandled future birthdates
    SUM(CASE WHEN bdate > GETDATE() THEN 1 ELSE 0 END) AS count_invalid_future_birthdates,
    
    -- 4. Check if any unexpected gender strings exist (Should only be Male, Female, N/A)
    SUM(CASE WHEN gen NOT IN ('Male', 'Female', 'N/A') THEN 1 ELSE 0 END) AS count_invalid_gender_formats

FROM silver.erp_cust_az12;

PRINT '>> Data Quality verification complete. (All error counts should ideally be 0)';
