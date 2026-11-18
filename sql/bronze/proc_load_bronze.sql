/*
===============================================================================
Stored Procedure: Load Bronze Layer (Bronze Ingestion Pipeline)
===============================================================================
Script Purpose:
    This stored procedure bulk loads data into the 'bronze' schema tables from 
    external CSV source files (CRM and ERP systems).

Execution Flow:
    1. Measures overall batch duration.
    2. Truncates each bronze table (ensuring idempotency / clean reload).
    3. Bulk loads raw records via PostgreSQL COPY commands.
    4. Computes individual table load duration.
    5. Traps runtime errors using an EXCEPTION block, logging error details
       and transaction rollbacks.

Parameters:
    None.

Usage:
    CALL bronze.load_bronze();
===============================================================================
*/

create or replace procedure bronze.load_bronze()
language plpgsql
as $$
DECLARE 
	batch_start_time TIMESTAMP;
	start_time TIMESTAMP;
begin
	batch_start_time = clock_timestamp();
	RAISE NOTICE '=======================================================';
	RAISE NOTICE 'Loading Bronze Layer...';
	RAISE NOTICE '=======================================================';
	
	RAISE NOTICE '-------------------------------------------------------';
	RAISE NOTICE 'Loading CRM Tables...';
	RAISE NOTICE '-------------------------------------------------------';
	
	start_time = clock_timestamp();
	RAISE NOTICE '>> Truncating Table: bronze.crm_cust_info';
	truncate table bronze.crm_cust_info;
	
	RAISE NOTICE '>> Inserting Data Into: bronze.crm_cust_info';
	COPY bronze.crm_cust_info
	FROM '/var/lib/pgsql/datasets/source_crm/cust_info.csv'
	WITH  (
	FORMAT csv,
	HEADER true, 
	DELIMITER ','
	);
	RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
	RAISE NOTICE '-------------------------------------------------------';
	
	start_time = clock_timestamp();
	RAISE NOTICE '>> Truncating Table: bronze.crm_prd_info';
	truncate table bronze.crm_prd_info;
	
	RAISE NOTICE '>> Inserting Data Into: bronze.crm_prd_info';
	COPY bronze.crm_prd_info
	FROM '/var/lib/pgsql/datasets/source_crm/prd_info.csv'
	WITH  (
	FORMAT csv,
	HEADER true, 
	DELIMITER ','
	);
	RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
	RAISE NOTICE '-------------------------------------------------------';
	
	start_time = clock_timestamp();
	RAISE NOTICE '>> Truncating Table: bronze.crm_sales_details';
	truncate table bronze.crm_sales_details;
	
	RAISE NOTICE '>> Inserting Data Into: bronze.crm_sales_details';
	COPY bronze.crm_sales_details
	FROM '/var/lib/pgsql/datasets/source_crm/sales_details.csv'
	WITH  (
	FORMAT csv,
	HEADER true, 
	DELIMITER ','
	);
	RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
	RAISE NOTICE '-------------------------------------------------------';
	
	RAISE NOTICE '-------------------------------------------------------';
	RAISE NOTICE 'CRM Data Loaded Succesfully!!!';
	RAISE NOTICE '-------------------------------------------------------';
	
	RAISE NOTICE '-------------------------------------------------------';
	RAISE NOTICE 'Loading ERP Tables...';
	RAISE NOTICE '-------------------------------------------------------';
	
	start_time = clock_timestamp();
	RAISE NOTICE '>> Truncating Table: bronze.erp_cust_az12';
	truncate table bronze.erp_cust_az12;
	
	RAISE NOTICE '>> Inserting Data Into: bronze.erp_cust_az12';
	COPY bronze.erp_cust_az12
	FROM '/var/lib/pgsql/datasets/source_erp/CUST_AZ12.csv'
	WITH  (
	FORMAT csv,
	HEADER true, 
	DELIMITER ','
	);
	RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
	RAISE NOTICE '-------------------------------------------------------';
	
	start_time = clock_timestamp();
	RAISE NOTICE '>> Truncating Table: bronze.erp_loc_a101';
	truncate table bronze.erp_loc_a101;
	
	RAISE NOTICE '>> Inserting Data Into: bronze.erp_loc_a101';
	COPY bronze.erp_loc_a101
	FROM '/var/lib/pgsql/datasets/source_erp/LOC_A101.csv'
	WITH  (
	FORMAT csv,
	HEADER true, 
	DELIMITER ','
	);
	RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
	RAISE NOTICE '-------------------------------------------------------';
	
	start_time = clock_timestamp();
	RAISE NOTICE '>> Truncating Table: bronze.erp_px_cat_g1v2';
	truncate table bronze.erp_px_cat_g1v2;
	
	RAISE NOTICE '>> Inserting Data Into: bronze.erp_px_cat_g1v2';
	COPY bronze.erp_px_cat_g1v2
	FROM '/var/lib/pgsql/datasets/source_erp/PX_CAT_G1V2.csv'
	WITH  (
	FORMAT csv,
	HEADER true, 
	DELIMITER ','
	);
	RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
	RAISE NOTICE '-------------------------------------------------------';
	
	RAISE NOTICE '-------------------------------------------------------';
	RAISE NOTICE 'ERP Data Loaded Succesfully!!!';
	RAISE NOTICE '-------------------------------------------------------';
	
	RAISE NOTICE '=======================================================';
	RAISE NOTICE 'Bronze Layer Loading Completed Successfully';
	RAISE NOTICE '=======================================================';
	RAISE NOTICE '>> Total Load Duration: %', (clock_timestamp() - batch_start_time);
	RAISE NOTICE '-------------------------------------------------------';
	
EXCEPTION
	WHEN OTHERS THEN
		RAISE NOTICE '=======================================================';
        RAISE NOTICE 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
        RAISE NOTICE 'Error Message: %', SQLERRM;
        RAISE NOTICE 'Error State:   %', SQLSTATE;
        RAISE NOTICE '=======================================================';

end;
$$;

