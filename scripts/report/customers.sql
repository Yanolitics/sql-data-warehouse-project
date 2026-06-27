-- ====================================================================
-- Project:     Data Warehouse - Gold Layer (Reporting Views)
-- Developer:   Yanolitics
-- Purpose:     Consolidate holistic customer profiles, demographic tiers, 
--              behavioral lifespans, recency intervals, and core financial KPIs.
-- Platform:    SQL Server (T-SQL)
-- ====================================================================

CREATE OR ALTER VIEW gold.report_customers AS

-- ====================================================================
-- PART 1: High-Performance Base Customer Aggregation
-- Purpose: Roll up historical transactions directly from the customer key.
--          Utilizes dimension-first driving tables to preserve zero-sales visibility.
-- ====================================================================
WITH cte_customer_metrics AS (
    SELECT
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        DATEDIFF(YEAR, c.birthdate, GETDATE()) AS age,
        COUNT(DISTINCT s.order_number) AS total_orders,
        ISNULL(SUM(s.sales_amount), 0) AS total_sales,
        ISNULL(SUM(s.quantity), 0) AS total_quantity,
        COUNT(DISTINCT s.product_key) AS total_products,
        MAX(s.order_date) AS last_order,
        DATEDIFF(MONTH, MIN(s.order_date), MAX(s.order_date)) AS lifespan
    FROM gold.dim_customer c
    LEFT JOIN gold.fact_sales s
        ON c.customer_key = s.customer_key
    GROUP BY 
        c.customer_key,
        c.customer_number,
        c.first_name,
        c.last_name,
        c.birthdate
)

-- ====================================================================
-- PART 2: Derived Behavioral Segmentation & Metric Transformations
-- Purpose: Calculate analytical demographics, RFM classifications,
--          and run-rate financial ratios (AOV / Monthly Budgets).
-- ====================================================================
SELECT
    customer_key,
    customer_number,
    customer_name,
    age,
    CASE 
        WHEN age < 20 THEN 'Under 20'
        WHEN age >= 20 AND age <= 29 THEN '20-29'
        WHEN age >= 30 AND age <= 39 THEN '30-39'
        WHEN age >= 40 AND age <= 49 THEN '40-49'
        WHEN age >= 50 AND age <= 59 THEN '50-59'
        WHEN age >= 60 AND age <= 65 THEN '60-65'
        ELSE 'Above 65'
    END AS age_category,
    CASE
        WHEN lifespan >= 12 AND total_sales >= 5000 THEN 'VIP'      
        WHEN lifespan >= 12 AND total_sales < 5000  THEN 'Regular'
        ELSE 'New'
    END AS customer_category,
    last_order, 
    DATEDIFF(MONTH, last_order, GETDATE()) AS recency,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    CASE 
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders 
    END AS avg_order_value,                                         
    CASE 
        WHEN total_sales = 0 THEN 0
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan 
    END AS avg_monthly_spend
FROM cte_customer_metrics;
GO
