/*
===============================================================================
Quality Checks: Silver Layer Data Validation
===============================================================================
Script Purpose:
    This script contains quality checks to validate data integrity, consistency, 
    uniqueness, and cleanliness across all tables in the 'silver' schema.

Checks Performed:
    - Null / Blank primary keys and grain violations.
    - Unwanted leading or trailing whitespace.
    - Standardization of categorical domains (Gender, Marital Status, Country, Maintenance).
    - Numeric validity (no negative or zero values in cost, price, quantity, sales).
    - Business rule math validation (Sales = Quantity * Price).
    - Date chronological integrity (order date <= ship date / due date, valid birthdates).
    - Cross-table referential integrity (CRM customer key matching ERP keys).

Expected Results:
    All validation queries designed to catch defects should return 0 rows (empty result set).
===============================================================================
*/

-- ============================================================================
-- CRM Tables Quality Checks
-- ============================================================================

-- ============================================================================
-- 1. Table: silver.crm_cust_info
-- ============================================================================

-- Check: Duplicates on primary key and nulls
-- Expectation: No Results (0 rows)
SELECT
    cst_id,
    COUNT(cst_id) 
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(cst_id) > 1 OR cst_id IS NULL;

-- Check: Unwanted leading/trailing whitespace in string columns
-- Expectation: No Results (0 rows)
SELECT *
FROM silver.crm_cust_info
WHERE cst_key != TRIM(cst_key);

SELECT *
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

SELECT *
FROM silver.crm_cust_info
WHERE cst_marital_status != TRIM(cst_marital_status);

SELECT *
FROM silver.crm_cust_info
WHERE cst_gndr != TRIM(cst_gndr);

-- Check: Domain values standardization
-- Expectation: Only 'Married', 'Single', 'n/a' and 'Male', 'Female', 'n/a'
SELECT DISTINCT 
    cst_marital_status,
    cst_gndr
FROM silver.crm_cust_info;


-- ============================================================================
-- 2. Table: silver.crm_prd_info
-- ============================================================================

-- Check: Duplicates on primary key and nulls
-- Expectation: No Results (0 rows)
SELECT
    prd_id,
    COUNT(prd_id) 
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(prd_id) > 1 OR prd_id IS NULL;

-- Check: Unwanted leading/trailing whitespace in string columns
-- Expectation: No Results (0 rows)
SELECT *
FROM silver.crm_prd_info
WHERE prd_key != TRIM(prd_key);

SELECT *
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

SELECT *
FROM silver.crm_prd_info
WHERE prd_line != TRIM(prd_line);

-- Check: Negative numbers or null costs
-- Expectation: No Results (0 rows)
SELECT *
FROM silver.crm_prd_info 
WHERE prd_cost IS NULL OR prd_cost < 0;

-- Check: Product line domain values
-- Expectation: Only 'Road', 'Mountain', 'Touring', 'Other Sales', 'n/a'
SELECT DISTINCT 
    prd_line
FROM silver.crm_prd_info;

-- Check: Chronological date order (start date must be <= end date)
-- Expectation: No Results (0 rows)
SELECT *
FROM silver.crm_prd_info
WHERE prd_start_dt > prd_end_dt;


-- ============================================================================
-- 3. Table: silver.crm_sales_details
-- ============================================================================

-- Check: Composite key duplicates and nulls (Grain: sls_ord_num + sls_prd_key)
-- Expectation: No Results (0 rows)
SELECT 
    sls_ord_num, 
    sls_prd_key, 
    COUNT(*)
FROM silver.crm_sales_details
GROUP BY sls_ord_num, sls_prd_key
HAVING COUNT(*) > 1 OR sls_ord_num IS NULL;

-- Check: Unwanted whitespace in order number and product key
-- Expectation: No Results (0 rows)
SELECT *
FROM silver.crm_sales_details csd 
WHERE sls_ord_num != TRIM(sls_ord_num);

SELECT *
FROM silver.crm_sales_details csd 
WHERE sls_prd_key != TRIM(sls_prd_key);

-- Check: Invalid date ranges (out of bounds or invalid casting)
-- Expectation: No Results (0 rows)
SELECT *
FROM silver.crm_sales_details
WHERE sls_order_dt IS NULL 
   OR sls_order_dt < '2004-11-16' 
   OR sls_order_dt > '2026-11-20';

SELECT *
FROM silver.crm_sales_details
WHERE sls_ship_dt IS NOT NULL 
  AND (sls_ship_dt < '2004-11-16' OR sls_ship_dt > '2026-11-20');

SELECT *
FROM silver.crm_sales_details
WHERE sls_due_dt IS NOT NULL 
  AND (sls_due_dt < '2004-11-16' OR sls_due_dt > '2026-11-20');

-- Check: Chronological order integrity (order date cannot be after ship or due date)
-- Expectation: No Results (0 rows)
SELECT *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt 
   OR sls_order_dt > sls_due_dt;

-- Check: Business math consistency (Sales = Quantity * Price) and non-negative numbers
-- Expectation: No Results (0 rows)
SELECT 
    sls_sales, 
    sls_quantity, 
    sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales <= 0 
   OR sls_quantity <= 0 
   OR sls_price <= 0
   OR sls_sales IS NULL 
   OR sls_quantity IS NULL 
   OR sls_price IS NULL
ORDER BY sls_sales, sls_quantity, sls_price;


-- ============================================================================
-- ERP Tables Quality Checks
-- ============================================================================

-- ============================================================================
-- 4. Table: silver.erp_cust_az12
-- ============================================================================

-- Check: Remaining 'NAS' prefix in customer IDs
-- Expectation: No Results (0 rows)
SELECT cid 
FROM silver.erp_cust_az12 
WHERE cid LIKE 'NAS%';

-- Check: Verification that transformation logic eliminated 100% of 'NAS' prefixes
-- Expectation: No Results (0 rows)
SELECT *
FROM (
    SELECT 
        CASE 
            WHEN cid LIKE 'NAS%' THEN SUBSTRING(TRIM(cid), 4)
            ELSE TRIM(cid)
        END AS cid
    FROM silver.erp_cust_az12
) t
WHERE cid LIKE 'NAS%';

-- Check: Invalid birthdates (future dates or older than 100 years)
-- Expectation: No Results (0 rows)
SELECT bdate
FROM silver.erp_cust_az12
WHERE bdate > CURRENT_DATE 
   OR bdate < CURRENT_DATE - INTERVAL '100 years';

-- Check: Distinct standardized gender values
-- Expectation: Only 'Male', 'Female', 'n/a'
SELECT DISTINCT 
    gen, 
    COUNT(*)
FROM silver.erp_cust_az12
GROUP BY gen;


-- ============================================================================
-- 5. Table: silver.erp_loc_a101
-- ============================================================================

-- Check: Foreign key referential integrity with CRM customer table
-- Expectation: No unmatched customer IDs (0 rows)
SELECT
    REPLACE(cid, '-', '') AS cid
FROM silver.erp_loc_a101 
WHERE REPLACE(cid, '-', '') NOT IN (SELECT cst_key FROM silver.crm_cust_info);

-- Check: Standardized country names distribution
-- Expectation: Clean country names (United States, Australia, UK, France, Germany, Canada, n/a)
SELECT DISTINCT
    cntry,
    COUNT(*)
FROM silver.erp_loc_a101
GROUP BY cntry
ORDER BY cntry;


-- ============================================================================
-- 6. Table: silver.erp_px_cat_g1v2
-- ============================================================================

-- Check: Duplicates, nulls, or unwanted whitespace in primary key 'id'
-- Expectation: No Results (0 rows)
SELECT 
    id, 
    COUNT(id)
FROM silver.erp_px_cat_g1v2 epcgv 
GROUP BY id
HAVING COUNT(id) > 1 OR id IS NULL OR TRIM(id) != id;

-- Check: Distinct categories
-- Expectation: Clean categories (Accessories, Bikes, Clothing, Components)
SELECT
    cat, 
    COUNT(cat)
FROM silver.erp_px_cat_g1v2 epcgv
GROUP BY cat;

-- Check: Unwanted spaces or nulls in category
-- Expectation: No Results (0 rows)
SELECT cat
FROM silver.erp_px_cat_g1v2 epcgv
WHERE TRIM(cat) != cat OR cat IS NULL;

-- Check: Distinct subcategories
-- Expectation: 37 clean subcategories
SELECT
    subcat, 
    COUNT(subcat)
FROM silver.erp_px_cat_g1v2 epcgv
GROUP BY subcat;

-- Check: Unwanted spaces or nulls in subcategory
-- Expectation: No Results (0 rows)
SELECT subcat
FROM silver.erp_px_cat_g1v2 epcgv
WHERE TRIM(subcat) != subcat OR subcat IS NULL;

-- Check: Maintenance flag domain values
-- Expectation: Only 'Yes' and 'No'
SELECT
    maintenance, 
    COUNT(maintenance)
FROM silver.erp_px_cat_g1v2
GROUP BY maintenance;

-- Check: Unwanted spaces in maintenance column
-- Expectation: No Results (0 rows)
SELECT maintenance
FROM silver.erp_px_cat_g1v2 epcgv
WHERE TRIM(maintenance) != maintenance;

-- Preview full clean table (Expectation: 37 rows)
SELECT * FROM silver.erp_px_cat_g1v2 epcgv;
