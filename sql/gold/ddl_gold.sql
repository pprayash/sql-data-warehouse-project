/*
===============================================================================
DDL Script: Create Gold Views (Kimball Star Schema)
===============================================================================
Script Purpose:
    This script creates the dimensional reporting views in the 'gold' schema.
    The Gold layer represents the presentation tier, implementing a Kimball
    Star Schema optimized for business intelligence, reporting, and analytics.

Views Created:
    - Dimensions:
        * gold.dim_customers  (Conformed Customer Dimension)
        * gold.dim_products   (Conformed Product Dimension)
    - Facts:
        * gold.fact_sales     (Central Sales Transaction Fact)

Architecture Note:
    - Layer: Gold (Presentation Tier)
    - Design: Kimball Star Schema
    - Storage: Virtual SQL Views (no redundant disk storage, zero-ETL automatic sync)
    - Keys: Generated surrogate keys (BIGINT) decouple analytics from source keys.
===============================================================================
*/

-- ============================================================================
-- Dimension Views
-- ============================================================================

-- ----------------------------------------------------------------------------
-- View: gold.dim_customers
-- Description: Conformed customer dimension integrating CRM profile, ERP 
--              demographics, and ERP geographic location records.
-- Grain: One row per unique customer profile.
-- Sources: silver.crm_cust_info, silver.erp_cust_az12, silver.erp_loc_a101
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW gold.dim_customers AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY ci.cst_id) AS customer_key,
    ci.cst_id AS customer_id,
    ci.cst_key AS customer_number,
    ci.cst_firstname AS first_name,
    ci.cst_lastname AS last_name,
    la.cntry AS country,
    ci.cst_marital_status AS marital_status,
    CASE
        WHEN ci.cst_gndr = 'n/a' THEN COALESCE(ca.gen, 'n/a')
        ELSE ci.cst_gndr
    END AS gender,
    ca.bdate AS birth_date,
    ci.cst_create_date AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
    ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
    ON ci.cst_key = la.cid;


-- ----------------------------------------------------------------------------
-- View: gold.dim_products
-- Description: Conformed product dimension representing the active catalog
--              with category taxonomy and unit costs (SCD Type 1 view).
-- Grain: One row per current/active product.
-- Sources: silver.crm_prd_info, silver.erp_px_cat_g1v2
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW gold.dim_products AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key,
    pn.prd_id AS product_id,
    pn.prd_key AS product_number,
    pn.prd_nm AS product_name,
    pn.cat_id AS category_id,
    pc.cat AS category,
    pc.subcat AS subcategory,
    pc.maintenance,
    pn.prd_cost AS cost,
    pn.prd_line AS product_line,
    pn.prd_start_dt AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
    ON pn.cat_id = pc.id
WHERE pn.prd_end_dt IS NULL;


-- ============================================================================
-- Fact Views
-- ============================================================================

-- ----------------------------------------------------------------------------
-- View: gold.fact_sales
-- Description: Central sales order transaction fact table with foreign key
--              references to Customer and Product dimensions.
-- Grain: One row per sales order line-item.
-- Sources: silver.crm_sales_details, gold.dim_products, gold.dim_customers
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW gold.fact_sales AS
SELECT 
    sd.sls_ord_num AS order_number,
    pr.product_key,
    cu.customer_key,
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt AS shipping_date,
    sd.sls_due_dt AS due_date,
    sd.sls_sales AS sales_amount,
    sd.sls_quantity AS quantity,
    sd.sls_price AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr
    ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
    ON sd.sls_cust_id = cu.customer_id;
