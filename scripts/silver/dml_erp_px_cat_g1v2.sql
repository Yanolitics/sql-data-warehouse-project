/*
===============================================================================
Script Name:         Load & Validate Silver Layer - erp_px_cat_g1v2
Purpose:             1. Loads product category and maintenance data from Bronze to Silver.
                     2. Standardizes layout and structure for product classification.
Warnings:            This is a full refresh script. Running this will wipe 
                     all existing data in silver.erp_px_cat_g1v2.
Author:              Timothy
===============================================================================
*/

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


-- ============================================================================
-- POST-LOAD DATA QUALITY CHECK
-- ============================================================================
PRINT '>> Running post-load data quality check...';

SELECT 
    COUNT(*) AS total_rows_checked,
    
    -- 1. Check for blank or missing IDs
    SUM(CASE WHEN id IS NULL OR id = '' THEN 1 ELSE 0 END) AS count_missing_ids,
    
    -- 2. Check for empty core category values
    SUM(CASE WHEN cat IS NULL OR cat = '' THEN 1 ELSE 0 END) AS count_missing_categories,
    
    -- 3. Check for empty subcategory values
    SUM(CASE WHEN subcat IS NULL OR subcat = '' THEN 1 ELSE 0 END) AS count_missing_subcategories

FROM silver.erp_px_cat_g1v2;

PRINT '>> Data Quality verification complete. (All error counts should ideally be 0)';
