/*
===============================================================================
Script Name:         Cleanse and Load silver.crm_prd_info
Purpose:             Cleanses, standardizes, and derives business categories 
                     for product data from the Bronze landing layer before 
                     loading it into the Silver layer.
Author:              Timothy
Create Date:         2026-06-23

Warning:             
    This script contains a TRUNCATE TABLE statement. Executing this will 
    completely wipe out all existing records within 'silver.crm_prd_info' 
    before performing the fresh batch load. Ensure no active reporting 
    dependencies are locked before running.
===============================================================================
*/

USE DataWarehouse;
GO

-- ==============================================================================
-- STEP 1: DATA CLEANING & STANDARDIZATION
-- ==============================================================================

-- Best Practice: Clear the Silver table before a full batch load to prevent data duplication
TRUNCATE TABLE silver.crm_prd_info;
GO

PRINT '>> Inserting cleansed data into: silver.crm_prd_info';

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
GO

PRINT '>> SUCCESS: silver.crm_prd_info loaded.';
PRINT '----------------------------------------------------------------------';


-- ==============================================================================
-- STEP 2: DATA VALIDATION AUDIT
-- ==============================================================================
PRINT '>> Running Quality Audit: Checking for Duplicates or NULL IDs...';

-- Best Practice: This query should return ZERO rows. 
-- If any rows appear, your primary identifier integrity check has failed.
SELECT 
    prd_id,
    COUNT(*) AS duplicate_count
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;
GO
