-- ====================================================================
-- Project:     Data Warehouse - Silver Quality Assurance Framework
-- Developer:   Yanolitics
-- Purpose:     Comprehensive post-load diagnostic audit & exception logging.
-- Strategy:    Deep data profiling, constraint validation, & referential integrity checks.
-- Usage:       Run immediately following EXEC silver.load_silver;
-- ====================================================================

USE DataWarehouse;
GO

    SET NOCOUNT ON;

    PRINT '======================================================================';
    PRINT '               STARTING SILVER LAYER COMPREHENSIVE AUDIT               ';
    PRINT '======================================================================';

    -- ─── SYSTEM 1: COMPLETENESS & UNIQUE KEY BREAKS ─────────────────────────
    PRINT '';
    PRINT '----------------------------------------------------------------------';
    PRINT ' SYSTEM 1: ENFORCEMENT OF UNIQUE KEYS & COMPLETENESS CHECK';
    PRINT '----------------------------------------------------------------------';
    
    SELECT 
        'silver.crm_cust_info' AS table_name,
        'Duplicate Customer IDs' AS audit_test,
        COUNT(cst_id) - COUNT(DISTINCT cst_id) AS exception_count
    FROM silver.crm_cust_info
    UNION ALL
    SELECT 
        'silver.crm_prd_info' AS table_name,
        'Duplicate Product Keys' AS audit_test,
        COUNT(*) - COUNT(DISTINCT prd_key) AS exception_count
    -- Note: Evaluates unique business lines since products can have historical timelines
    FROM (SELECT prd_key, prd_start_dt FROM silver.crm_prd_info) p
    UNION ALL
    SELECT 
        'silver.crm_cust_info' AS table_name,
        'Missing Customer Keys (NULL/Blank)' AS audit_test,
        SUM(CASE WHEN cst_key IS NULL OR cst_key = '' THEN 1 ELSE 0 END) AS exception_count
    FROM silver.crm_cust_info
    UNION ALL
    SELECT 
        'silver.crm_prd_info' AS table_name,
        'Missing Product Names' AS audit_test,
        SUM(CASE WHEN prd_nm IS NULL OR prd_nm = '' THEN 1 ELSE 0 END) AS exception_count
    FROM silver.crm_prd_info;


    -- ─── SYSTEM 2: DOMAIN RANGE & VALIDATION RULES ──────────────────────────
    PRINT '';
    PRINT '----------------------------------------------------------------------';
    PRINT ' SYSTEM 2: DOMAIN STRUCTURE & VALIDATION ASSERTIONS';
    PRINT '----------------------------------------------------------------------';

    SELECT 
        'silver.crm_cust_info' AS table_name,
        'Unstandardized Gender Codes' AS audit_test,
        SUM(CASE WHEN cst_gndr NOT IN ('Male', 'Female', 'N/A') THEN 1 ELSE 0 END) AS exception_count
    FROM silver.crm_cust_info
    UNION ALL
    SELECT 
        'silver.crm_cust_info' AS table_name,
        'Unstandardized Marital Status' AS audit_test,
        SUM(CASE WHEN cst_marital_status NOT IN ('Single', 'Married', 'N/A') THEN 1 ELSE 0 END) AS exception_count
    FROM silver.crm_cust_info
    UNION ALL
    SELECT 
        'silver.erp_cust_az12' AS table_name,
        'Extreme/Outlier Birthdates (< Year 1910)' AS audit_test,
        SUM(CASE WHEN bdate < '1910-01-01' THEN 1 ELSE 0 END) AS exception_count
    FROM silver.erp_cust_az12
    UNION ALL
    SELECT 
        'silver.erp_loc_a101' AS table_name,
        'Unmapped Country Formats' AS audit_test,
        SUM(CASE WHEN cntry = 'N/A' THEN 1 ELSE 0 END) AS exception_count
    FROM silver.erp_loc_a101;


    -- ─── SYSTEM 3: BUSINESS RULE & TIMELINE CHRONOLOGY ──────────────────────
    PRINT '';
    PRINT '----------------------------------------------------------------------';
    PRINT ' SYSTEM 3: BUSINESS RULES & CHRONOLOGICAL INTEGRITY';
    PRINT '----------------------------------------------------------------------';

    SELECT 
        'silver.crm_prd_info' AS table_name,
        'Timeline Clashes (End Date before Start Date)' AS audit_test,
        SUM(CASE WHEN prd_end_dt < prd_start_dt THEN 1 ELSE 0 END) AS exception_count
    FROM silver.crm_prd_info
    UNION ALL
    SELECT 
        'silver.crm_sales_details' AS table_name,
        'Logistical Chronology Breaks (Shipped Before Ordered)' AS audit_test,
        SUM(CASE WHEN sls_ship_dt < sls_order_dt THEN 1 ELSE 0 END) AS exception_count
    FROM silver.crm_sales_details
    UNION ALL
    SELECT 
        'silver.crm_sales_details' AS table_name,
        'Negative Values In Financial Transactions' AS audit_test,
        SUM(CASE WHEN sls_sales < 0 OR sls_quantity < 0 OR sls_price < 0 THEN 1 ELSE 0 END) AS exception_count
    FROM silver.crm_sales_details
    UNION ALL
    SELECT 
        'silver.crm_sales_details' AS table_name,
        'Gross Financial Math Inconsistencies (Sales != Qty * Price)' AS audit_test,
        SUM(CASE WHEN ABS(sls_sales - (sls_quantity * sls_price)) > 0.05 THEN 1 ELSE 0 END) AS exception_count
    FROM silver.crm_sales_details;


    -- ─── SYSTEM 4: REFERENTIAL INTEGRITY (ORPHANS REPORT) ───────────────────
    PRINT '';
    PRINT '----------------------------------------------------------------------';
    PRINT ' SYSTEM 4: CROSS-DOMAIN REFERENTIAL INTEGRITY (ORPHANS REPORT)';
    PRINT '----------------------------------------------------------------------';

    SELECT 
        'silver.crm_sales_details -> silver.crm_cust_info' AS data_relationship,
        'Orphaned Transaction Sales pointing to Missing Customer IDs' AS audit_test,
        COUNT(*) AS exception_count
    FROM silver.crm_sales_details s
    LEFT JOIN silver.crm_cust_info c ON s.sls_cust_id = c.cst_id
    WHERE c.cst_id IS NULL
    UNION ALL
    SELECT 
        'silver.crm_sales_details -> silver.crm_prd_info' AS data_relationship,
        'Orphaned Transaction Sales pointing to Missing Product Keys' AS audit_test,
        COUNT(*) AS exception_count
    FROM silver.crm_sales_details s
    LEFT JOIN silver.crm_prd_info p ON s.sls_prd_key = p.prd_key
    WHERE p.prd_key IS NULL
    UNION ALL
    SELECT 
        'silver.erp_loc_a101 -> silver.crm_cust_info' AS data_relationship,
        'ERP Customer Locations Missing completely from Master CRM Customer Records' AS audit_test,
        COUNT(*) AS exception_count
    FROM silver.erp_loc_a101 l
    LEFT JOIN silver.crm_cust_info c ON l.cid = c.cst_key
    WHERE c.cst_key IS NULL;


    PRINT '';
    PRINT '======================================================================';
    PRINT '               SILVER LAYER QUALITY AUDIT COMPLETED                   ';
    PRINT '               (Exception counts should ideally be 0)                 ';
    PRINT '======================================================================';

GO
