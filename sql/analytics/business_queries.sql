/*
===============================================================================
Analytical Queries: Business Intelligence & Reporting (Gold Layer)
===============================================================================
Script Purpose:
    This script answers core analytical business questions defined in the
    project plan by querying the Kimball Star Schema views in the 'gold' layer
    (gold.fact_sales, gold.dim_products, gold.dim_customers).

Queries Included:
    1. Global Executive Sales Overview & KPIs
    2. Product Performance & Ranking (Top 10 & Bottom 10)
    3. Customer Demographic & Cohort Segmentation (Gender & Age Brackets)
    4. Geographic Market & Customer Spend Analysis
    5. Product Hierarchy & Category Revenue Share
    6. Time-Series & Month-over-Month (MoM) Revenue Growth

Architecture Note:
    - Target Layer: Gold Presentation Views only (single source of truth).
    - Grain Awareness: gold.fact_sales is at the order line-item grain, so
      COUNT(DISTINCT ...) is used for order and customer counts.
===============================================================================
*/


-- ============================================================================
-- 1. Global Executive Sales Overview & KPIs
-- ============================================================================
-- Business Question: What is our overall historical business performance
--                    across revenue, volume, orders, customers, AOV, and ASP?
SELECT
    SUM(sales_amount) AS total_revenue,
    SUM(quantity) AS total_units_sold,
    COUNT(DISTINCT order_number) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    -- Cast to NUMERIC before dividing to avoid PostgreSQL integer truncation
    ROUND(SUM(sales_amount)::NUMERIC / NULLIF(COUNT(DISTINCT order_number), 0), 2) AS average_order_value,
    ROUND(SUM(sales_amount)::NUMERIC / NULLIF(SUM(quantity), 0), 2) AS average_selling_price
FROM gold.fact_sales;


-- ============================================================================
-- 2. Product Performance & Ranking (Top 10 & Bottom 10)
-- ============================================================================
-- Business Question: Which products drive the highest revenue and which are
--                    the lowest-performing items in the catalog?
-- Technique: Dual DENSE_RANK() window functions preserve ties without gaps.
SELECT
    CASE
        WHEN top_rank <= 10 THEN 'Top 10'
        WHEN bottom_rank <= 10 THEN 'Bottom 10'
    END AS performance_tier,
    product_name,
    category,
    total_revenue,
    total_units_sold,
    total_orders,
    top_rank,
    bottom_rank
FROM (
    SELECT
        p.product_name,
        p.category,
        SUM(s.sales_amount) AS total_revenue,
        SUM(s.quantity) AS total_units_sold,
        COUNT(DISTINCT s.order_number) AS total_orders,
        DENSE_RANK() OVER (ORDER BY SUM(s.sales_amount) DESC) AS top_rank,
        DENSE_RANK() OVER (ORDER BY SUM(s.sales_amount) ASC) AS bottom_rank
    FROM gold.fact_sales AS s
    LEFT JOIN gold.dim_products AS p
        ON s.product_key = p.product_key
    GROUP BY
        p.product_name,
        p.category
) AS product_rankings
WHERE top_rank <= 10
   OR bottom_rank <= 10
ORDER BY total_revenue DESC;


-- ============================================================================
-- 3. Customer Demographic & Cohort Segmentation
-- ============================================================================
-- Business Question: How is revenue distributed across customer gender and
--                    age cohorts?
-- Technique: AGE() derives brackets; SUM() OVER () computes global share %.
SELECT
    gender,
    age_group,
    total_revenue,
    distinct_customers,
    ROUND(
        total_revenue * 100.0 / NULLIF(SUM(total_revenue) OVER (), 0),
        2
    ) AS revenue_percentage
FROM (
    SELECT
        c.gender,
        CASE
            WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date)) < 25 THEN 'Under 25'
            WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date)) BETWEEN 25 AND 34 THEN '25-34'
            WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date)) BETWEEN 35 AND 49 THEN '35-49'
            WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.birth_date)) >= 50 THEN '50 and Above'
            ELSE 'Unknown'
        END AS age_group,
        SUM(s.sales_amount) AS total_revenue,
        COUNT(DISTINCT s.customer_key) AS distinct_customers
    FROM gold.fact_sales AS s
    LEFT JOIN gold.dim_customers AS c
        ON s.customer_key = c.customer_key
    GROUP BY
        c.gender,
        age_group
) AS cohort_sales
ORDER BY total_revenue DESC;


-- ============================================================================
-- 4. Geographic Market & Customer Spend Analysis
-- ============================================================================
-- Business Question: Which countries generate the most revenue and have the
--                    highest average spend per customer?
SELECT
    c.country,
    SUM(s.sales_amount) AS total_revenue,
    COUNT(DISTINCT s.order_number) AS total_orders,
    COUNT(DISTINCT s.customer_key) AS distinct_customers,
    ROUND(
        SUM(s.sales_amount)::NUMERIC / NULLIF(COUNT(DISTINCT s.customer_key), 0),
        2
    ) AS average_spend_per_customer
FROM gold.fact_sales AS s
LEFT JOIN gold.dim_customers AS c
    ON s.customer_key = c.customer_key
GROUP BY c.country
ORDER BY total_revenue DESC;


-- ============================================================================
-- 5. Product Hierarchy & Category Revenue Share
-- ============================================================================
-- Business Question: How much does each subcategory contribute to its parent
--                    category's total revenue?
-- Technique: SUM() OVER (PARTITION BY category) computes per-category subtotals.
WITH subcategory_sales AS (
    SELECT
        p.category,
        p.subcategory,
        SUM(s.sales_amount) AS subcategory_revenue,
        SUM(s.quantity) AS total_units_sold
    FROM gold.fact_sales AS s
    LEFT JOIN gold.dim_products AS p
        ON s.product_key = p.product_key
    GROUP BY
        p.category,
        p.subcategory
)
SELECT
    category,
    subcategory,
    subcategory_revenue,
    total_units_sold,
    SUM(subcategory_revenue) OVER (PARTITION BY category) AS category_total_revenue,
    ROUND(
        subcategory_revenue * 100.0 / NULLIF(SUM(subcategory_revenue) OVER (PARTITION BY category), 0),
        2
    ) AS category_share_pct
FROM subcategory_sales
ORDER BY
    category ASC,
    subcategory_revenue DESC;


-- ============================================================================
-- 6. Time-Series & Month-over-Month (MoM) Revenue Growth
-- ============================================================================
-- Business Question: How is monthly revenue trending over time, and what is
--                    the month-over-month percentage growth rate?
-- Technique: Chained CTEs truncate dates to month and use LAG() for prior month.
WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS sales_month,
        SUM(sales_amount) AS monthly_revenue,
        COUNT(DISTINCT order_number) AS total_orders
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_date)::DATE
),
monthly_comparison AS (
    SELECT
        sales_month,
        monthly_revenue,
        total_orders,
        LAG(monthly_revenue) OVER (ORDER BY sales_month) AS prev_month_revenue
    FROM monthly_sales
)
SELECT
    sales_month,
    monthly_revenue,
    prev_month_revenue,
    total_orders,
    ROUND(
        ((monthly_revenue - prev_month_revenue) * 100.0 / NULLIF(prev_month_revenue, 0)),
        2
    ) AS mom_growth_pct
FROM monthly_comparison
ORDER BY sales_month ASC;
