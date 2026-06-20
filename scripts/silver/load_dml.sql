/*
===============================================================================
Script Name:         Cleanse and Load silver.crm_cust_info
Purpose:             Cleanses, standardizes, and deduplicates customer data 
                     from the Bronze landing layer before loading it into the 
                     Silver layer.
Author:              Timothy
Create Date:         2026-06-21

Warning:             
    This script contains a TRUNCATE TABLE statement. Executing this will 
    completely wipe out all existing records within 'silver.crm_cust_info' 
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
TRUNCATE TABLE silver.crm_cust_info;
GO

PRINT '>> Inserting cleansed data into: silver.crm_cust_info';

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
WHERE flag_last = 1; -- Only insert the most recent, valid records
GO

PRINT '>> SUCCESS: silver.crm_cust_info loaded.';
PRINT '----------------------------------------------------------------------';


-- ==============================================================================
-- STEP 2: DATA VALIDATION AUDIT
-- ==============================================================================
PRINT '>> Running Quality Audit: Checking for Duplicates or NULL IDs...';

-- Best Practice: This query should return ZERO rows. 
-- If any rows are returned, the upstream deduplication or NULL-filtering failed.
SELECT 
    cst_id,
    COUNT(*) AS duplicate_count
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;
GO
