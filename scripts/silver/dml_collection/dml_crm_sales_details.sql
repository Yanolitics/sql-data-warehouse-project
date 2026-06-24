/*
===============================================================================
Script Name:         Load and Enrich silver.crm_sales_details
Purpose:             Cleanses, standardizes, and performs cascading financial 
                     imputation on CRM sales entries before final ingestion.
Author:              Timothy
===============================================================================
*/

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

        -- 🛡️ DATE PROTECTION & SANITY FILTER LAYER
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
    FROM Bronze.crm_sales_details
) AS t;

PRINT '>> Silver layer refresh complete!';
