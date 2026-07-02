-- ====================================================================
-- Project:     Data Warehouse - Gold Layer (Advanced Data Analytics)
-- Developer:   Yanolitics
-- Purpose:     Execute advanced business intelligence metrics including
--              Time-Series Trends, Rolling Windows, YoY Growth, 
--              Part-to-Whole Contributions, and Dynamic Cohort Segmentation.
-- Platform:    SQL Server (T-SQL)
-- ====================================================================

USE DataWarehouse;
GO

PRINT '>> Commencing Advanced Analytics Framework Execution';
GO

/* ====================================================================
   PART 1: Change-Over-Time (Trend Analysis)
   Purpose: Analyze core velocity metrics broken down by monthly cohorts
==================================================================== */
PRINT ' -> Executing Part 1: Change-Over-Time Trends';

SELECT
    YEAR(order_date) AS order_year,
    MONTH(order_date) AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 
    YEAR(order_date), 
    MONTH(order_date)
ORDER BY 
    order_year, 
    order_month;


/* ====================================================================
   PART 2: Cumulative & Rolling Window Analysis
   Purpose: Calculate running historical totals and moving price baselines
==================================================================== */
PRINT ' -> Executing Part 2: Cumulative Reporting';

WITH cte_monthly_base AS (
    SELECT
        DATETRUNC(MONTH, order_date) AS order_month,
        SUM(sales_amount) AS total_sales,
        AVG(price) AS average_price
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(MONTH, order_date)
)
SELECT
    order_month,
    total_sales,
    SUM(total_sales) OVER (
        PARTITION BY YEAR(order_month) 
        ORDER BY order_month
    ) AS running_total_sales,
    AVG(average_price) OVER (
        PARTITION BY YEAR(order_month) 
        ORDER BY order_month
    ) AS moving_average_price
FROM cte_monthly_base
ORDER BY order_month;


/* ====================================================================
   PART 3: Performance Analysis (Year-over-Year Tracking)
   Purpose: Measure product performance variances against prior periods
            and macro average benchmarks
==================================================================== */
PRINT ' -> Executing Part 3: Year-over-Year Performance Evaluation';

WITH cte_sales AS (
    SELECT
        YEAR(s.order_date) AS order_year,
        p.product_name,
        SUM(s.sales_amount) AS current_year
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_product p
        ON s.product_key = p.product_key
    WHERE s.order_date IS NOT NULL
    GROUP BY 
        YEAR(s.order_date),
        p.product_name
),
cte_yoy_metrics AS (
    SELECT
        order_year,
        product_name,
        current_year,
        LAG(current_year, 1, 0) OVER (
            PARTITION BY product_name 
            ORDER BY order_year
        ) AS previous_year,
        AVG(current_year) OVER (
            PARTITION BY product_name
        ) AS average_sales
    FROM cte_sales
)
SELECT
    order_year,
    product_name,
    current_year,
    previous_year,
    (current_year - previous_year) AS yearly_change,
    CASE 
        WHEN (current_year - previous_year) > 0 THEN 'Increase Sales'
        WHEN (current_year - previous_year) < 0 THEN 'Decrease Sales'
        ELSE 'Static / NA'
    END AS performance,
    average_sales,
    (current_year - average_sales) AS diff_avg,
    CASE 
        WHEN (current_year - average_sales) > 0 THEN 'Above Average'
        WHEN (current_year - average_sales) < 0 THEN 'Below Average'
        ELSE 'Average'
    END AS average_change
FROM cte_yoy_metrics
ORDER BY 
    product_name, 
    order_year;


/* ====================================================================
   PART 4: Part-to-Whole Analysis
   Purpose: Determine category structural weights relative to gross revenue
==================================================================== */
PRINT ' -> Executing Part 4: Component Contribution Weights';

WITH cte_sales_category AS (
    SELECT
        p.category,
        SUM(s.sales_amount) AS total_sales
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_product p
        ON s.product_key = p.product_key
    GROUP BY p.category
)
SELECT
    category,
    total_sales,
    SUM(total_sales) OVER() AS overall_sales,
    CONCAT(ROUND(CAST(total_sales AS FLOAT) / SUM(total_sales) OVER() * 100, 2), '%') AS part
FROM cte_sales_category
ORDER BY total_sales DESC;


/* ====================================================================
   PART 5: Advanced Operational Segmentation
   Purpose: Category banding for pricing architecture and behavioral RFM 
            customer volume summaries.
==================================================================== */
PRINT ' -> Executing Part 5: Product & Customer Cohort Segmentation';

-- ⚡ Section A: Product Pricing Tiers
SELECT
    segment,
    COUNT(*) AS total_products
FROM (
    SELECT
        product_name,
        cost,
        CASE 
            WHEN cost <= 1000 THEN '1-1000'                     
            WHEN cost > 1000 AND cost <= 2000 THEN '1001-2000'
            ELSE 'Above 2000'
        END AS segment
    FROM gold.dim_product
) AS t_product_tier
GROUP BY segment
ORDER BY total_products DESC;

-- ⚡ Section B: Behavioral Customer Volumetrics
WITH cte_customer_history AS (
    SELECT
        customer_key,
        MIN(order_date) AS first_order,
        MAX(order_date) AS last_order,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS duration,
        SUM(sales_amount) AS total_spent
    FROM gold.fact_sales
    WHERE customer_key IS NOT NULL
    GROUP BY customer_key
),
cte_customer_segmentation AS (
    SELECT 
        customer_key,
        CASE
            WHEN duration >= 12 AND total_spent >= 5000 THEN 'VIP'   
            WHEN duration >= 12 AND total_spent < 5000  THEN 'Regular'
            ELSE 'New'
        END AS segment
    FROM cte_customer_history
)
SELECT
    segment,
    COUNT(*) AS total_customers
FROM cte_customer_segmentation
GROUP BY segment
ORDER BY total_customers DESC;

PRINT '>> Core Advanced Analytics Script Execution Finalized Successfully.';
GO
