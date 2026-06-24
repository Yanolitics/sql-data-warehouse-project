/*
===============================================================================
Script Name:         Load & Validate Silver Layer - erp_loc_a101
Purpose:             1. Cleanses and loads location data from Bronze to Silver.
                     2. Removes hyphens from IDs and standardizes country names.
                     3. Filters out IDs that do not match silver.crm_cust_info.
Warnings:            This is a full refresh script. Running this will wipe 
                     all existing data in silver.erp_loc_a101.
Author:              Timothy
===============================================================================
*/

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


-- ============================================================================
-- POST-LOAD DATA QUALITY CHECK
-- ============================================================================
PRINT '>> Running post-load data quality check...';

SELECT 
    COUNT(*) AS total_rows_checked,
    
    -- 1. Check for blank or missing IDs
    SUM(CASE WHEN cid IS NULL OR cid = '' THEN 1 ELSE 0 END) AS count_missing_customer_ids,
    
    -- 2. Check if any hyphens managed to sneak through
    SUM(CASE WHEN cid LIKE '%-%' THEN 1 ELSE 0 END) AS count_escaped_hyphens,
    
    -- 3. Check if any unexpected country strings exist
    SUM(CASE WHEN cntry NOT IN ('Germany', 'United States', 'United Kingdom', 'Australia', 'Canada', 'France', 'N/A') THEN 1 ELSE 0 END) AS count_invalid_country_formats

FROM silver.erp_loc_a101;

PRINT '>> Data Quality verification complete. (All error counts should ideally be 0)';
