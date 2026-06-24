-- ====================================================================
-- Project:     Data Warehouse - Gold Quality Assurance Framework
-- Developer:   Yanolitics
-- Purpose:     Comprehensive post-deployment dimensional model validation.
-- Strategy:    Validates surrogate key uniqueness, conformed dimension domains,
--              fact measure consistency, and referential integrity (NULL keys).
-- Usage:       Run immediately following the deployment of Gold views.
-- ====================================================================

USE DataWarehouse;
GO

    SET NOCOUNT ON;

    PRINT '======================================================================';
    PRINT '                 STARTING GOLD LAYER DIMENSIONAL AUDIT                ';
    PRINT '======================================================================';

    -- ─── SYSTEM 1: SURROGATE KEY UNIQUE & COMPLETENESS CHECKS ───────────────
    PRINT '';
    PRINT '----------------------------------------------------------------------';
    PRINT ' SYSTEM 1: SURROGATE KEY UNIQUENESS & COMPLETENESS';
    PRINT '----------------------------------------------------------------------';
    
    SELECT 
        'gold.dim_customer' AS dimensional_object,
        'Duplicate Customer Surrogate Keys' AS quality_check,
        COUNT(customer_key) - COUNT(DISTINCT customer_key) AS exception_count
    FROM gold.dim_customer
    UNION ALL
    SELECT 
        'gold.dim_product' AS dimensional_object,
        'Duplicate Product Surrogate Keys' AS quality_check,
        COUNT(product_key) - COUNT(DISTINCT product_key) AS exception_count
    FROM gold.dim_product
    UNION ALL
    SELECT 
        'gold.dim_customer' AS dimensional_object,
        'NULL Surrogate Keys Detected' AS quality_check,
        SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) AS exception_count
    FROM gold.dim_customer
    UNION ALL
    SELECT 
        'gold.dim_product' AS dimensional_object,
        'NULL Surrogate Keys Detected' AS quality_check,
        SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END) AS exception_count
    FROM gold.dim_product;


    -- ─── SYSTEM 2: CONFORMED DIMENSION DOMAIN VALIDATIONS ───────────────────
    PRINT '';
    PRINT '----------------------------------------------------------------------';
    PRINT ' SYSTEM 2: CONFORMED DIMENSION ATTRIBUTE DOMAINS';
    PRINT '----------------------------------------------------------------------';

    SELECT 
        'gold.dim_customer' AS dimensional_object,
        'Gender Non-conformed Leakage (Expected: Male/Female/N/A)' AS quality_check,
        SUM(CASE WHEN gender NOT IN ('Male', 'Female', 'N/A') THEN 1 ELSE 0 END) AS exception_count
    FROM gold.dim_customer
    UNION ALL
    SELECT 
        'gold.dim_customer' AS dimensional_object,
        'Marital Status Non-conformed Leakage (Expected: Single/Married/N/A)' AS quality_check,
        SUM(CASE WHEN marital_status NOT IN ('Single', 'Married', 'N/A') THEN 1 ELSE 0 END) AS exception_count
    FROM gold.dim_customer
    UNION ALL
    SELECT 
        'gold.dim_product' AS dimensional_object,
        'Negative Base Product Cost Anomalies' AS quality_check,
        SUM(CASE WHEN cost < 0 THEN 1 ELSE 0 END) AS exception_count
    FROM gold.dim_product
    UNION ALL
    SELECT 
        'gold.dim_product' AS dimensional_object,
        'Missing Category or Subcategory Context Mapping' AS quality_check,
        SUM(CASE WHEN category IS NULL OR subcategory IS NULL THEN 1 ELSE 0 END) AS exception_count
    FROM gold.dim_product;


    -- ─── SYSTEM 3: FACT MEASURE & DATE LOGIC CONSISTENCY ────────────────────
    PRINT '';
    PRINT '----------------------------------------------------------------------';
    PRINT ' SYSTEM 3: FACT MEASURE METRICS & DATE CHRONOLOGY';
    PRINT '----------------------------------------------------------------------';

    SELECT 
        'gold.fact_sales' AS dimensional_object,
        'Logistical Sequence Errors (Shipping Date Before Order Date)' AS quality_check,
        SUM(CASE WHEN shipping_date < order_date THEN 1 ELSE 0 END) AS exception_count
    FROM gold.fact_sales
    UNION ALL
    SELECT 
        'gold.fact_sales' AS dimensional_object,
        'Negative Sales Revenue or Quantity Flags' AS quality_check,
        SUM(CASE WHEN sales_amount < 0 OR quantity < 0 THEN 1 ELSE 0 END) AS exception_count
    FROM gold.fact_sales
    UNION ALL
    SELECT 
        'gold.fact_sales' AS dimensional_object,
        'Revenue Discrepancy Faults (Sales Amount != Qty * Price)' AS quality_check,
        SUM(CASE WHEN ABS(sales_amount - (quantity * price)) > 0.05 THEN 1 ELSE 0 END) AS exception_count
    FROM gold.fact_sales;


    -- ─── SYSTEM 4: STAR SCHEMA REFERENTIAL INTEGRITY (NULL SURROGATES) ──────
    PRINT '';
    PRINT '----------------------------------------------------------------------';
    PRINT ' SYSTEM 4: STAR SCHEMA REFERENTIAL INTEGRITY (ORPHAN KEY TRACKING)';
    PRINT '----------------------------------------------------------------------';
    -- 💡 Context: Because Gold views use LEFT JOINs to connect dimensions, 
    -- any unmatched business IDs result in NULL surrogate keys in the Fact table.

    SELECT 
        'gold.fact_sales -> gold.dim_customer' AS star_relationship,
        'Unmapped Customer Records (NULL customer_key in Fact)' AS quality_check,
        SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) AS exception_count
    FROM gold.fact_sales
    UNION ALL
    SELECT 
        'gold.fact_sales -> gold.dim_product' AS star_relationship,
        'Unmapped Product Records (NULL product_key in Fact)' AS quality_check,
        SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END) AS exception_count
    FROM gold.fact_sales;


    PRINT '';
    PRINT '======================================================================';
    PRINT '                 GOLD LAYER QUALITY AUDIT COMPLETED                   ';
    PRINT '               (Exception counts should ideally be 0)                 ';
    PRINT '======================================================================';
GO
