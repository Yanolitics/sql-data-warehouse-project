/*
===============================================================================
Script Name:         Cleanse, Load, and Audit silver.crm_prd_info
Purpose:             Cleanses, standardizes, and derives business categories 
                     for product data from the Bronze landing layer, then 
                     immediately runs a comprehensive 5-part data quality audit.
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

PRINT '======================================================================';
PRINT '          PROCESSING SILVER LAYER: LOADING & AUDITING PRODUCT DATA    ';
PRINT '======================================================================';
PRINT '';

-- ==============================================================================
-- STEP 1: DATA CLEANING & STANDARDIZATION
-- ==============================================================================
PRINT '----------------------------------------------------------------------';
PRINT ' STEP 1: DATA CLEANING & LOAD';
PRINT '----------------------------------------------------------------------';

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
-- STEP 2: COMPREHENSIVE DATA QUALITY AUDIT SUITE
-- ==============================================================================
PRINT '';
PRINT '----------------------------------------------------------------------';
PRINT ' STEP 2: DATA QUALITY SUITE';
PRINT '----------------------------------------------------------------------';

-- CHECK 2.1: UNIQUE IDENTIFIER & NULL AUDIT
PRINT '>> [CHECK 1/5] Checking for Duplicate or NULL Product IDs...';
SELECT 
    prd_id, 
    COUNT(*) AS duplicate_count
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;
PRINT '----------------------------------------------------------------------';

-- CHECK 2.2: STRING PADDING & EMPTY VALUE AUDIT (TRIM CHECK)
PRINT '>> [CHECK 2/5] Checking for Hidden Spaces or Empty Product Names...';
SELECT 
    prd_id, 
    prd_nm,
    LEN(prd_nm) AS current_length
FROM silver.crm_prd_info
WHERE 
    prd_nm LIKE ' %'          -- Captures leading spaces
    OR prd_nm LIKE '% '       -- Captures trailing spaces
    OR prd_nm = ''            -- Captures empty strings
    OR prd_nm IS NULL;        -- Captures missing names
PRINT '----------------------------------------------------------------------';

-- CHECK 2.3: DATE LINEAGE & TIMELINE INTEGRITY AUDIT
PRINT '>> [CHECK 3/5] Checking Timeline Validity (Start Date vs End Date)...';
SELECT 
    prd_id, 
    prd_key, 
    prd_start_dt, 
    prd_end_dt
FROM silver.crm_prd_info
WHERE prd_start_dt > prd_end_dt;
PRINT '----------------------------------------------------------------------';

-- CHECK 2.4: DATA FORMATTING & EXTRACTED KEY AUDIT
PRINT '>> [CHECK 4/5] Checking Formatted Category IDs (cat_id)...';
SELECT 
    prd_id, 
    cat_id, 
    LEN(cat_id) AS cat_id_length
FROM silver.crm_prd_info
WHERE 
    cat_id IS NULL 
    OR LEN(cat_id) != 5 
    OR cat_id LIKE '%-%';     -- Flags if a hyphen slipped past the REPLACE function
PRINT '----------------------------------------------------------------------';

-- CHECK 2.5: BUSINESS LOGIC SANITY AUDIT (COSTS & CODES)
PRINT '>> [CHECK 5/5] Checking for Negative Costs or Invalid Product Lines...';
SELECT 
    prd_id, 
    prd_cost, 
    prd_line
FROM silver.crm_prd_info
WHERE 
    prd_cost < 0 
    OR prd_line = 'N/A';
PRINT '----------------------------------------------------------------------';


PRINT '';
PRINT '======================================================================';
PRINT '               SILVER LAYER LOAD & AUDIT PIPELINE COMPLETED           ';
PRINT '======================================================================';
GO
