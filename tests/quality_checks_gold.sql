/*
===============================================================================
Quality Checks: Gold Layer (Star Schema Validation)
===============================================================================
Script Purpose:
    This script performs quality assurance checks on the 'gold' presentation tier.
    It validates dimensional integrity, duplicate-free joins, cross-system 
    reconciliation, and referential integrity between fact and dimension views.

Checks Performed:
    1. Dimension Joins: Ensures multi-table joins in dim_customers and dim_products
       produce 0 duplicate rows.
    2. Data Reconciliation: Validates gender conflict handling between CRM and ERP.
    3. Domain Consistency: Confirms clean categorical domain values in dimensions.
    4. Referential Integrity: Verifies that 100% of sales transactions in fact_sales
       resolve to valid surrogate keys (zero orphaned records / zero null keys).

Expected Results:
    All defect-detection queries should return 0 rows (empty result set).
===============================================================================
*/

-- ============================================================================
-- 1. Table / View: gold.dim_customers
-- ============================================================================

-- Check: Duplication when joining CRM profiles with ERP demographics and location
-- Expectation: No Results (0 rows)
SELECT 
    cst_id, 
    COUNT(*) 
FROM (
    SELECT 
        ci.cst_id,
        ci.cst_key,
        ci.cst_firstname,
        ci.cst_lastname,
        ci.cst_marital_status,
        ci.cst_gndr,
        ci.cst_create_date,
        ca.bdate,
        ca.gen,
        la.cntry
    FROM silver.crm_cust_info ci
    LEFT JOIN silver.erp_cust_az12 ca
        ON ci.cst_key = ca.cid
    LEFT JOIN silver.erp_loc_a101 la
        ON ci.cst_key = la.cid
) t
GROUP BY cst_id 
HAVING COUNT(*) > 1;

-- Check: Cross-system gender integration and consistency between CRM and ERP
-- Purpose: Inspect where CRM and ERP disagree or where one source fills the other's gaps
SELECT 
    ci.cst_gndr,
    ca.gen,
    COUNT(*) AS record_count
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
    ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
    ON ci.cst_key = la.cid
WHERE ci.cst_gndr != ca.gen OR ci.cst_gndr IS NULL OR ca.gen IS NULL
GROUP BY ci.cst_gndr, ca.gen;

-- Check: Preview dimension output
-- Expectation: 18,484 rows
SELECT * FROM gold.dim_customers;

-- Check: Final standardized gender domain values in the view
-- Expectation: Only 'Male', 'Female', 'n/a'
SELECT DISTINCT gender FROM gold.dim_customers;


-- ============================================================================
-- 2. Table / View: gold.dim_products
-- ============================================================================

-- Check: Duplication when joining product catalog with category hierarchy (active products)
-- Expectation: No Results (0 rows)
SELECT 
    prd_key, 
    COUNT(*) 
FROM (
    SELECT  
        pn.prd_id,
        pn.cat_id,
        pn.prd_key,
        pn.prd_nm,
        pn.prd_cost,
        pn.prd_line,
        pn.prd_start_dt,
        pc.cat,
        pc.subcat,
        pc.maintenance
    FROM silver.crm_prd_info pn
    LEFT JOIN silver.erp_px_cat_g1v2 pc
        ON pn.cat_id = pc.id
    WHERE prd_end_dt IS NULL
) t
GROUP BY prd_key
HAVING COUNT(*) > 1;

-- Check: Preview product dimension output
-- Expectation: 295 unique active products
SELECT * FROM gold.dim_products;


-- ============================================================================
-- 3. Table / View: gold.fact_sales
-- ============================================================================

-- Check: Preview fact sales output
-- Expectation: 60,398 rows
SELECT * FROM gold.fact_sales;

-- Check: Referential Integrity & Orphan Key Validation
-- Purpose: Verify that EVERY sales row maps to a valid customer and product surrogate key
-- Expectation: No Results (0 rows) - Zero orphaned transactions
SELECT * 
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE c.customer_key IS NULL OR p.product_key IS NULL;
