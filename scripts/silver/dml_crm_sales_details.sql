/*
===============================================================================
Script Name:         Load and Enrich silver.crm_sales_details
Purpose:             Cleanses, standardizes, and performs cascading financial 
                     imputation on CRM sales entries before final ingestion.
Author:              Timothy
===============================================================================
*/

-- Step 1: Base Cleansing & Stage 1 Financial Corrections
WITH cleansed_sales_base AS (
    SELECT
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        sls_quantity,
        sls_price AS raw_price,
        
        -- Resilient INT-to-DATE transformations using TRY_CAST
        TRY_CAST(CAST(sls_order_dt AS VARCHAR(8)) AS DATE) AS raw_order_dt,
        TRY_CAST(CAST(sls_ship_dt  AS VARCHAR(8)) AS DATE) AS raw_ship_dt,
        TRY_CAST(CAST(sls_due_dt   AS VARCHAR(8)) AS DATE) AS raw_due_dt,
        
        -- Financial Correction Layer 1: Clean total sales first
        CASE 
            WHEN sls_sales IS NULL 
                 OR sls_sales <= 0 
                 OR sls_sales != sls_quantity * ABS(sls_price) 
            THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END AS corrected_sls_sales
    FROM Bronze.crm_sales_details
)

-- Step 2: Final Ingestion with Windowed Date Healing & Layer 2 Financials
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
    
    -- Date Imputation: Evaluates and heals date gaps across matching orders
    MAX(raw_order_dt) OVER (PARTITION BY sls_ord_num) AS sls_order_dt,
    MAX(raw_ship_dt)  OVER (PARTITION BY sls_ord_num) AS sls_ship_dt,
    MAX(raw_due_dt)   OVER (PARTITION BY sls_ord_num) AS sls_due_dt,
    
    corrected_sls_sales AS sls_sales,
    sls_quantity,
    
    -- Financial Correction Layer 2: Safely uses the GUARANTEED corrected sales figure
    CASE 
        WHEN raw_price IS NULL 
             OR raw_price <= 0 
        THEN corrected_sls_sales / NULLIF(sls_quantity, 0)
        ELSE raw_price
    END AS sls_price

FROM cleansed_sales_base
