/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
	This script drops and recreates the raw staging tables in the 'bronze' schema.
	
Sources:
    - CRM System:
        * bronze.crm_cust_info      (Customer Profiles)
        * bronze.crm_prd_info       (Product Catalog)
        * bronze.crm_sales_details  (Sales Transactions)
    - ERP System:
        * bronze.erp_cust_az12      (Customer Demographics)
        * bronze.erp_loc_a101       (Customer Geography/Location)
        * bronze.erp_px_cat_g1v2    (Product Category Hierarchy)

Architecture Note:
    - Layer: Bronze (Raw Staging)
    - Ingestion Philosophy: High-tolerance ingestion. Data is stored in raw 
      or relaxed formats (VARCHAR/INT) to prevent load crashes.
    - All data cleansing, deduplication, and type validation are deferred 
      to the Silver layer.
===============================================================================
*/

--CRM Tables

DROP TABLE IF EXISTS bronze.crm_cust_info;
create table bronze.crm_cust_info (
cst_id INT,
cst_key VARCHAR(50),
cst_firstname VARCHAR(50),
cst_lastname VARCHAR(50),
cst_marital_status VARCHAR(50),
cst_gndr VARCHAR(50),
cst_create_date DATE
);

DROP TABLE IF EXISTS bronze.crm_prd_info;
create table bronze.crm_prd_info (
prd_id INT,
prd_key VARCHAR(50),
prd_nm VARCHAR(50),
prd_cost INT,
prd_line VARCHAR(50),
prd_start_dt DATE,
prd_end_dt DATE
);

DROP TABLE IF EXISTS bronze.crm_sales_details;
create table bronze.crm_sales_details (
sls_ord_num VARCHAR(50),
sls_prd_key VARCHAR(50),
sls_cust_id INT,
sls_order_dt INT,
sls_ship_dt INT,
sls_due_dt INT,
sls_sales INT,
sls_quantity INT,
sls_price INT
);

-- ERP Tables

DROP TABLE IF EXISTS bronze.erp_cust_az12;
create table bronze.erp_cust_az12 (
cid VARCHAR(50),
bdate date,
gen VARCHAR(50)
);

DROP TABLE IF EXISTS bronze.erp_loc_a101;
create table bronze.erp_loc_a101 (
cid VARCHAR(50),
cntry varchar(50)
);

DROP TABLE IF EXISTS bronze.erp_px_cat_g1v2;
create table bronze.erp_px_cat_g1v2 (
id varchar(50),
cat varchar(50),
subcat varchar(50),
maintenance varchar(50)
);




