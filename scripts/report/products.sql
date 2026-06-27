-- ====================================================================
-- Project:     Data Warehouse - Gold Layer (Reporting Views)
-- Developer:   Yanolitics
-- Purpose:     Consolidate comprehensive product performance profiles,
--              inventory lifespans, sales velocity, and product-level KPIs.
-- Platform:    SQL Server (T-SQL)
-- ====================================================================

CREATE OR ALTER VIEW gold.report_products AS

-- ====================================================================
-- PART 1: High-Performance Base Product Aggregation
-- Purpose: Roll up historical transactions directly from the product key.
--          Utilizes dimension-first driving tables to preserve zero-sales visibility.
-- ====================================================================
WITH cte_product_metrics AS (
    SELECT
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost,
        MAX(s.order_date) AS last_sale_date,
        COUNT(DISTINCT s.order_number) AS total_orders,
        COUNT(DISTINCT s.customer_key) AS total_customers,
        DATEDIFF(MONTH, MIN(s.order_date), MAX(s.order_date)) AS lifespan,
        ISNULL(SUM(s.sales_amount), 0) AS total_sales,
        ISNULL(SUM(s.quantity), 0) AS total_quantity,
        ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity,0)),1) AS avg_selling_price
    FROM gold.dim_product p
    LEFT JOIN gold.fact_sales s
        ON p.product_key = s.product_key
    GROUP BY
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
)

-- ====================================================================
-- PART 2: Derived Performance Tiers & Velocity Transformations
-- Purpose: Calculate analytical execution thresholds and run-rate 
--          revenue metrics.
-- ====================================================================
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    last_sale_date,
    DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency,
    CASE 
        WHEN total_sales <= 500000 THEN 'Low-Performer'         
        WHEN total_sales > 500000 AND total_sales <= 900000 THEN 'Mid-Performer'
        ELSE 'High-Performer'
    END AS prod_performance,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    avg_selling_price,
    CASE 
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders 
    END AS avg_order_revenue,
    CASE 
        WHEN total_sales = 0 THEN 0
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan 
    END AS avg_monthly_revenue                                    
FROM cte_product_metrics
WHERE last_sale_date IS NOT NULL;
GO
