-- Advanced Data Analysis

-- PART 1: Change-Over-Time (trend)

SELECT
YEAR(order_date) AS order_year,
MONTH(order_date) AS order_month,
SUM(sales_amount) total_sales,
COUNT(DISTINCT customer_key) as total_customers,
SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE YEAR(order_date) IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date) 

-- PART 2: Cumulative Analysis

SELECT
order_date,
total_sales,
SUM(total_sales) OVER(PARTITION BY YEAR(order_date) ORDER BY order_date) as running_total_sales,
AVG(average_price) OVER(PARTITION BY YEAR(order_date) ORDER BY order_date) as moving_average_price
FROM(
SELECT
DATETRUNC(month, order_date) AS order_date,
SUM(sales_amount) AS total_sales,
AVG(price) AS average_price
FROM gold.fact_sales
WHERE YEAR(order_date) IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
)t

-- PART 3: Performance Analysis (Year over Year analysis)

WITH cte_sales AS
(
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
)

SELECT
*,
LAG(current_year,1,0) OVER (PARTITION BY product_name ORDER BY order_year) previous_year,
current_year - LAG(current_year,1,0) OVER (PARTITION BY product_name ORDER BY order_year) yearly_change,
CASE WHEN current_year - LAG(current_year,1,0) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase Sales'
	WHEN current_year - LAG(current_year,1,0) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease Sales'
	ELSE 'NA'
END AS performance,
AVG (current_year) OVER (PARTITION BY product_name) average_sales,
current_year - AVG (current_year) OVER (PARTITION BY product_name) AS diff_avg,
CASE WHEN current_year - AVG (current_year) OVER (PARTITION BY product_name) > 0 THEN 'Above Average'
	WHEN current_year - AVG (current_year) OVER (PARTITION BY product_name) < 0 THEN 'Below Average'
	ELSE 'Average'
END AS average_change
FROM cte_sales
ORDER BY product_name,order_year

-- PART 4: Part-to-Whole Analysis
-- Which categories contribute the most to overall sales?

WITH cte_sales_category AS
(
SELECT
p.category,
SUM(s.sales_amount) total_sales
FROM gold.fact_sales s
LEFT JOIN gold.dim_product p
ON s.product_key = p.product_key
GROUP BY p.category	
)

SELECT
category,
total_sales,
SUM(total_sales) OVER() overall_sales,
CONCAT(ROUND(CAST(total_sales AS FLOAT) / SUM(total_sales) OVER() * 100,2 ),'%')AS part
FROM cte_sales_category
ORDER BY Total_sales DESC

-- PART 5: Data Segmentation
-- Segment products into cost ranges and count how many products fall into each segment
SELECT
segment,
COUNT(segment)
FROM (
SELECT
product_name,
cost,
CASE WHEN cost < 1000 THEN '1-1000'
WHEN cost BETWEEN 1001 AND 2000 THEN '1001-2000'
ELSE 'Above 2000'
END as segment
FROM gold.dim_product

)t
GROUP BY segment

/*Group customers into three segments based on their spending behavior:
    - VIP: Customers with at least 12 months of history and spending more than €5,000.
    - Regular: Customers with at least 12 months of history but spending €5,000 or less.
    - New: Customers with a lifespan less than 12 months.
And find the total number of customers by each group
*/

WITH cte_customer_history AS
(
SELECT
c.customer_key,
MIN(s.order_date) first_order,
MAX(s.order_date) last_order,
DATEDIFF(MONTH,MIN(s.order_date),MAX(s.order_date)) duration,
SUM(s.sales_amount) total_spent
FROM gold.fact_sales s	
LEFT JOIN gold.dim_customer c
ON s.customer_key = c.customer_key
GROUP BY c.customer_key
),

cte_customer_segmentation AS
(
SELECT 
customer_key,
total_spent,
duration,
CASE
	WHEN duration >= 12 AND total_spent > 5000 THEN 'VIP'
	WHEN duration >= 12 AND total_spent < 5000 THEN 'Regular'
	ELSE 'New'
END AS segment
FROM cte_customer_history
)

SELECT
segment,
COUNT(segment) total
FROM cte_customer_segmentation
GROUP BY segment
