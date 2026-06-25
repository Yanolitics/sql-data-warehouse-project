-- ====================================================================
-- Project:     Data Warehouse - Gold Layer Tier 1 Practice
-- Developer:   Yanolitics
-- Purpose:     Refactored Analytical Queries with Applied Best Practices
-- ====================================================================

USE DataWarehouse;
GO

-- ────────────────────────────────────────────────────────────────────
-- EXERCISE 1: Find products (name and number) that have never sold
-- ────────────────────────────────────────────────────────────────────
PRINT '>> Running Exercise 1: Unsold Products';

SELECT 
    p.product_number,
    p.product_name
FROM gold.dim_product p
WHERE NOT EXISTS (
    SELECT 1 
    FROM gold.fact_sales fs 
    WHERE fs.product_key = p.product_key
);


-- ────────────────────────────────────────────────────────────────────
-- EXERCISE 2: Performance Metrics by Demographics (Marital & Gender)
-- ────────────────────────────────────────────────────────────────────
PRINT '>> Running Exercise 2: Demographic Purchasing Power';

SELECT
    c.marital_status,
    c.gender,
    SUM(s.sales_amount) AS total_revenue, 
    SUM(s.quantity)     AS total_quantity, 
    SUM(s.sales_amount) / COUNT(DISTINCT s.order_number) AS average_order_value
FROM gold.fact_sales s
LEFT JOIN gold.dim_customer c 
    ON s.customer_key = c.customer_key
GROUP BY 
    c.marital_status, 
    c.gender
ORDER BY 
    total_revenue DESC;


-- ────────────────────────────────────────────────────────────────────
-- EXERCISE 3: Product Line Catalog Depth vs Actual Sales Performance
-- ────────────────────────────────────────────────────────────────────
PRINT '>> Running Exercise 3: Product Line Depth';

SELECT
    p.product_line,
    COUNT(DISTINCT p.product_key) AS total_products,
    COALESCE(SUM(s.quantity), 0)  AS total_quantity,
    COALESCE(SUM(s.sales_amount), 0) AS total_sales
FROM gold.dim_product p
LEFT JOIN gold.fact_sales s
    ON p.product_key = s.product_key
GROUP BY 
    p.product_line
ORDER BY 
    total_sales DESC;


-- ────────────────────────────────────────────────────────────────────
-- EXERCISE 4: Top 10 Spending Customers
-- ────────────────────────────────────────────────────────────────────
PRINT '>> Running Exercise 4: Top 10 Customers';

SELECT TOP 10
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer,
    c.country,
    SUM(s.sales_amount) AS total_spent
FROM gold.dim_customer c
INNER JOIN gold.fact_sales s 
    ON c.customer_key = s.customer_key
GROUP BY
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name),
    c.country
ORDER BY 
    total_spent DESC;
GO
