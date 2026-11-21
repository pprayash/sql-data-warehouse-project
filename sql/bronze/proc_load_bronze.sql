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

CREATE OR REPLACE PROCEDURE bronze.load_bronze()
LANGUAGE plpgsql
AS $$
DECLARE 
    batch_start_time TIMESTAMP;
    start_time TIMESTAMP;
BEGIN
    batch_start_time := clock_timestamp();
    RAISE NOTICE '=======================================================';
    RAISE NOTICE 'Loading Bronze Layer...';
    RAISE NOTICE '=======================================================';
    
    -- ========================================================================
    -- Loading CRM Tables
    -- ========================================================================
    RAISE NOTICE '-------------------------------------------------------';
    RAISE NOTICE 'Loading CRM Tables...';
    RAISE NOTICE '-------------------------------------------------------';
    
    -- ------------------------------------------------------------------------
    -- Table 1: bronze.crm_cust_info
    -- ------------------------------------------------------------------------
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: bronze.crm_cust_info';
    TRUNCATE TABLE bronze.crm_cust_info;
    
    RAISE NOTICE '>> Inserting Data Into: bronze.crm_cust_info';
    COPY bronze.crm_cust_info
    FROM '/var/lib/pgsql/datasets/source_crm/cust_info.csv'
    WITH (
        FORMAT csv,
        HEADER true, 
        DELIMITER ','
    );

    RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
    RAISE NOTICE '-------------------------------------------------------';
    
    -- ------------------------------------------------------------------------
    -- Table 2: bronze.crm_prd_info
    -- ------------------------------------------------------------------------
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: bronze.crm_prd_info';
    TRUNCATE TABLE bronze.crm_prd_info;
    
    RAISE NOTICE '>> Inserting Data Into: bronze.crm_prd_info';
    COPY bronze.crm_prd_info
    FROM '/var/lib/pgsql/datasets/source_crm/prd_info.csv'
    WITH (
        FORMAT csv,
        HEADER true, 
        DELIMITER ','
    );

    RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
    RAISE NOTICE '-------------------------------------------------------';
    
    -- ------------------------------------------------------------------------
    -- Table 3: bronze.crm_sales_details
    -- ------------------------------------------------------------------------
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: bronze.crm_sales_details';
    TRUNCATE TABLE bronze.crm_sales_details;
    
    RAISE NOTICE '>> Inserting Data Into: bronze.crm_sales_details';
    COPY bronze.crm_sales_details
    FROM '/var/lib/pgsql/datasets/source_crm/sales_details.csv'
    WITH (
        FORMAT csv,
        HEADER true, 
        DELIMITER ','
    );

    RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
    RAISE NOTICE '-------------------------------------------------------';
    
    RAISE NOTICE '-------------------------------------------------------';
    RAISE NOTICE 'CRM Data Loaded Successfully!!!';
    RAISE NOTICE '-------------------------------------------------------';
    
    -- ========================================================================
    -- Loading ERP Tables
    -- ========================================================================
    RAISE NOTICE '-------------------------------------------------------';
    RAISE NOTICE 'Loading ERP Tables...';
    RAISE NOTICE '-------------------------------------------------------';
    
    -- ------------------------------------------------------------------------
    -- Table 4: bronze.erp_cust_az12
    -- ------------------------------------------------------------------------
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: bronze.erp_cust_az12';
    TRUNCATE TABLE bronze.erp_cust_az12;
    
    RAISE NOTICE '>> Inserting Data Into: bronze.erp_cust_az12';
    COPY bronze.erp_cust_az12
    FROM '/var/lib/pgsql/datasets/source_erp/CUST_AZ12.csv'
    WITH (
        FORMAT csv,
        HEADER true, 
        DELIMITER ','
    );

    RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
    RAISE NOTICE '-------------------------------------------------------';
    
    -- ------------------------------------------------------------------------
    -- Table 5: bronze.erp_loc_a101
    -- ------------------------------------------------------------------------
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: bronze.erp_loc_a101';
    TRUNCATE TABLE bronze.erp_loc_a101;
    
    RAISE NOTICE '>> Inserting Data Into: bronze.erp_loc_a101';
    COPY bronze.erp_loc_a101
    FROM '/var/lib/pgsql/datasets/source_erp/LOC_A101.csv'
    WITH (
        FORMAT csv,
        HEADER true, 
        DELIMITER ','
    );

    RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
    RAISE NOTICE '-------------------------------------------------------';
    
    -- ------------------------------------------------------------------------
    -- Table 6: bronze.erp_px_cat_g1v2
    -- ------------------------------------------------------------------------
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating Table: bronze.erp_px_cat_g1v2';
    TRUNCATE TABLE bronze.erp_px_cat_g1v2;
    
    RAISE NOTICE '>> Inserting Data Into: bronze.erp_px_cat_g1v2';
    COPY bronze.erp_px_cat_g1v2
    FROM '/var/lib/pgsql/datasets/source_erp/PX_CAT_G1V2.csv'
    WITH (
        FORMAT csv,
        HEADER true, 
        DELIMITER ','
    );

    RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
    RAISE NOTICE '-------------------------------------------------------';
    
    RAISE NOTICE '-------------------------------------------------------';
    RAISE NOTICE 'ERP Data Loaded Successfully!!!';
    RAISE NOTICE '-------------------------------------------------------';
    
    -- ========================================================================
    -- Summary & Completion
    -- ========================================================================
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
        RAISE;
END;
$$;
