/*
===============================================================================
Stored Procedure: Load Silver Layer (Silver ETL Pipeline)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL process to populate the 'silver' schema
    tables from the raw 'bronze' schema.

Actions Performed:
    - Measures overall batch duration and individual table load durations.
    - Truncates each silver table to ensure idempotent, repeatable execution.
    - Applies transformation, data cleansing, standardization, and deduplication:
        1. crm_cust_info: Deduplicates on cst_id, trims whitespace, standardizes
           gender and marital status codes.
        2. crm_prd_info: Derives cat_id from prd_key, normalizes negative costs,
           maps product lines, computes prd_end_dt using LEAD().
        3. crm_sales_details: Validates composite grain, enforces date bounds &
           chronological integrity, mathematically guarantees Sales = Quantity * Price.
        4. erp_cust_az12: Strips 'NAS' prefix, nulls invalid future birthdates,
           standardizes gender codes.
        5. erp_loc_a101: Strips hyphens from cid to match CRM keys, standardizes
           country names (maps US/USA to United States, DE to Germany).
        6. erp_px_cat_g1v2: Trims strings, handles blank categories with COALESCE,
           normalizes maintenance flags to 'Yes'/'No'.
    - Logs detailed notices with timestamps and elapsed durations.
    - Handles runtime exceptions via EXCEPTION block, logging error details.

Parameters:
    None.

Usage:
    CALL silver.load_silver();
===============================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE 
    batch_start_time TIMESTAMP;
    start_time TIMESTAMP;
BEGIN
    batch_start_time := clock_timestamp();
    RAISE NOTICE '=======================================================';
    RAISE NOTICE 'Loading Silver Layer...';
    RAISE NOTICE '=======================================================';
    
    -- ========================================================================
    -- Loading CRM Tables
    -- ========================================================================
    RAISE NOTICE '-------------------------------------------------------';
    RAISE NOTICE 'Loading CRM Tables...';
    RAISE NOTICE '-------------------------------------------------------';
    
    -- ------------------------------------------------------------------------
    -- Table 1: silver.crm_cust_info
    -- ------------------------------------------------------------------------
    start_time := clock_timestamp();
    
    RAISE NOTICE '>> Truncating table silver.crm_cust_info';
    TRUNCATE TABLE silver.crm_cust_info;
    
    RAISE NOTICE '>> Inserting data into silver.crm_cust_info';
    INSERT INTO silver.crm_cust_info (
        cst_id, 
        cst_key, 
        cst_firstname, 
        cst_lastname, 
        cst_marital_status, 
        cst_gndr, 
        cst_create_date
    )
    SELECT 
        cst_id,
        TRIM(cst_key) AS cst_key,
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname) AS cst_lastname,
        CASE 
            WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
            WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
            ELSE 'n/a'
        END AS cst_marital_status,
        CASE 
            WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
            WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
            ELSE 'n/a'
        END AS cst_gndr,
        cst_create_date
    FROM (
        SELECT
            *, 	
            ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
        FROM bronze.crm_cust_info
        WHERE cst_id IS NOT NULL
    ) t
    WHERE flag_last = 1;

    RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
    RAISE NOTICE '-------------------------------------------------------';
    
    -- ------------------------------------------------------------------------
    -- Table 2: silver.crm_prd_info
    -- ------------------------------------------------------------------------
    start_time := clock_timestamp();
    
    RAISE NOTICE '>> Truncating table silver.crm_prd_info';
    TRUNCATE TABLE silver.crm_prd_info;
    
    RAISE NOTICE '>> Inserting data into silver.crm_prd_info';
    INSERT INTO silver.crm_prd_info (
        prd_id,
        cat_id,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt
    )
    SELECT
        prd_id,
        REPLACE(SUBSTRING(TRIM(prd_key), 1, 5), '-', '_') AS cat_id,
        SUBSTRING(TRIM(prd_key), 7, LENGTH(TRIM(prd_key))) AS prd_key,
        TRIM(prd_nm) AS prd_nm,
        CASE WHEN prd_cost < 0 OR prd_cost IS NULL THEN 0 ELSE prd_cost END AS prd_cost,
        CASE 
            WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
            WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
            WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
            WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
            ELSE 'n/a'
        END AS prd_line,
        prd_start_dt::DATE,
        LEAD(prd_start_dt::DATE) OVER (PARTITION BY prd_key ORDER BY prd_start_dt ASC) - 1 AS prd_end_dt
    FROM (
        SELECT 
            *,
            ROW_NUMBER() OVER (PARTITION BY prd_id ORDER BY prd_start_dt DESC) AS flag_last
        FROM bronze.crm_prd_info
        WHERE prd_id IS NOT NULL
    ) t
    WHERE flag_last = 1;

    RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
    RAISE NOTICE '-------------------------------------------------------';
    
    -- ------------------------------------------------------------------------
    -- Table 3: silver.crm_sales_details
    -- ------------------------------------------------------------------------
    start_time := clock_timestamp();
    
    RAISE NOTICE '>> Truncating table silver.crm_sales_details';
    TRUNCATE TABLE silver.crm_sales_details;
    
    RAISE NOTICE '>> Inserting data into silver.crm_sales_details';
    INSERT INTO silver.crm_sales_details (
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        sls_order_dt,
        sls_ship_dt,
        sls_due_dt,
        sls_sales,
        sls_quantity,
        sls_price
    )
    SELECT
        TRIM(sls_ord_num) AS sls_ord_num,
        NULLIF(TRIM(sls_prd_key), '') AS sls_prd_key,
        sls_cust_id,
        CASE
            WHEN clean_order_dt_int IS NULL THEN NULL
            ELSE clean_order_dt_int::TEXT::DATE
        END AS sls_order_dt,
        CASE
            WHEN sls_ship_dt <= 0 OR LENGTH(sls_ship_dt::TEXT) != 8 OR sls_ship_dt < 20041116 OR sls_ship_dt > 20261120 THEN NULL
            WHEN clean_order_dt_int IS NOT NULL AND clean_order_dt_int > sls_ship_dt THEN NULL
            ELSE sls_ship_dt::TEXT::DATE
        END AS sls_ship_dt,
        CASE
            WHEN sls_due_dt <= 0 OR LENGTH(sls_due_dt::TEXT) != 8 OR sls_due_dt < 20041116 OR sls_due_dt > 20261120 THEN NULL
            WHEN clean_order_dt_int IS NOT NULL AND clean_order_dt_int > sls_due_dt THEN NULL
            ELSE sls_due_dt::TEXT::DATE
        END AS sls_due_dt,
        clean_sls_quantity * clean_sls_price AS sls_sales,
        clean_sls_quantity AS sls_quantity,
        clean_sls_price AS sls_price
    FROM (
        SELECT
            *,
            CASE
                WHEN sls_order_dt <= 0 OR LENGTH(sls_order_dt::TEXT) != 8 OR sls_order_dt < 20041116 OR sls_order_dt > 20261120 THEN NULL
                ELSE sls_order_dt
            END AS clean_order_dt_int,
            CASE
                WHEN sls_price <= 0 OR sls_price IS NULL
                    THEN ABS(sls_sales) / COALESCE(NULLIF(ABS(sls_quantity), 0), 1)
                ELSE ABS(sls_price)
            END AS clean_sls_price,
            COALESCE(NULLIF(ABS(sls_quantity), 0), 1) AS clean_sls_quantity,
            ROW_NUMBER() OVER (
                PARTITION BY sls_ord_num, sls_prd_key
                ORDER BY sls_order_dt DESC
            ) AS flag_last
        FROM bronze.crm_sales_details
        WHERE sls_ord_num IS NOT NULL AND TRIM(sls_ord_num) != ''
    ) t
    WHERE flag_last = 1;

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
    -- Table 4: silver.erp_cust_az12
    -- ------------------------------------------------------------------------
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating table silver.erp_cust_az12';
    TRUNCATE TABLE silver.erp_cust_az12;

    RAISE NOTICE '>> Inserting data into silver.erp_cust_az12';
    INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
    SELECT 
        CASE 
            WHEN cid LIKE 'NAS%' THEN SUBSTRING(TRIM(cid), 4)
            ELSE TRIM(cid)
        END AS cid,
        CASE 
            WHEN bdate > CURRENT_DATE OR bdate < CURRENT_DATE - INTERVAL '100 years' THEN NULL
            ELSE bdate
        END AS bdate,
        CASE 
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
            ELSE 'n/a'
        END AS gen
    FROM (
        SELECT 
            *,
            ROW_NUMBER() OVER (
                PARTITION BY CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(TRIM(cid), 4) ELSE TRIM(cid) END 
                ORDER BY 
                    CASE 
                        WHEN bdate IS NOT NULL AND gen IS NOT NULL THEN 1 
                        WHEN bdate IS NOT NULL THEN 2 
                        WHEN gen IS NOT NULL THEN 3 
                        ELSE 4 
                    END
            ) AS flag_last
        FROM bronze.erp_cust_az12
        WHERE cid IS NOT NULL AND TRIM(cid) != ''
    ) t
    WHERE flag_last = 1;

    RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
    RAISE NOTICE '-------------------------------------------------------';
    
    -- ------------------------------------------------------------------------
    -- Table 5: silver.erp_loc_a101
    -- ------------------------------------------------------------------------
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating table silver.erp_loc_a101';
    TRUNCATE TABLE silver.erp_loc_a101;

    RAISE NOTICE '>> Inserting data into silver.erp_loc_a101';
    INSERT INTO silver.erp_loc_a101 (
        cid,
        cntry
    )
    SELECT 
        REPLACE(TRIM(cid), '-', '') AS cid, 
        CASE 
            WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
            WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
            WHEN TRIM(cntry) IN ('Australia', 'Canada', 'France', 'Germany', 'United Kingdom', 'United States') THEN TRIM(cntry)
            ELSE 'n/a'
        END AS cntry
    FROM (
        SELECT 
            *,
            ROW_NUMBER() OVER (
                PARTITION BY REPLACE(TRIM(cid), '-', '')
                ORDER BY 
                    CASE 
                        WHEN NULLIF(TRIM(cntry), '') IS NOT NULL THEN 1  
                        ELSE 2
                    END
            ) AS flag_last
        FROM bronze.erp_loc_a101
        WHERE cid IS NOT NULL AND TRIM(cid) != ''
    ) t
    WHERE flag_last = 1;

    RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
    RAISE NOTICE '-------------------------------------------------------';
    
    -- ------------------------------------------------------------------------
    -- Table 6: silver.erp_px_cat_g1v2
    -- ------------------------------------------------------------------------
    start_time := clock_timestamp();

    RAISE NOTICE '>> Truncating table silver.erp_px_cat_g1v2';
    TRUNCATE TABLE silver.erp_px_cat_g1v2;

    RAISE NOTICE '>> Inserting data into silver.erp_px_cat_g1v2';
    INSERT INTO silver.erp_px_cat_g1v2 (
        id,
        cat,
        subcat,
        maintenance
    )
    SELECT
        TRIM(id) AS id, 
        COALESCE(NULLIF(TRIM(cat), ''), 'n/a') AS cat,
        COALESCE(NULLIF(TRIM(subcat), ''), 'n/a') AS subcat,
        CASE 
            WHEN UPPER(TRIM(maintenance)) IN ('YES', 'Y') THEN 'Yes'
            WHEN UPPER(TRIM(maintenance)) IN ('NO', 'N') THEN 'No'
            ELSE 'n/a'
        END AS maintenance
    FROM (
        SELECT 
            *,
            ROW_NUMBER() OVER (
                PARTITION BY TRIM(id)
                ORDER BY 
                    CASE 
                        WHEN NULLIF(TRIM(cat), '') IS NOT NULL AND NULLIF(TRIM(subcat), '') IS NOT NULL THEN 1 
                        WHEN NULLIF(TRIM(cat), '') IS NOT NULL THEN 2 
                        WHEN NULLIF(TRIM(subcat), '') IS NOT NULL THEN 3 
                        ELSE 4 
                    END
            ) AS flag_last
        FROM bronze.erp_px_cat_g1v2
        WHERE id IS NOT NULL AND TRIM(id) != ''
    ) t
    WHERE flag_last = 1;

    RAISE NOTICE '>> Load Duration: %', (clock_timestamp() - start_time);
    RAISE NOTICE '-------------------------------------------------------';
    
    RAISE NOTICE '-------------------------------------------------------';
    RAISE NOTICE 'ERP Data Loaded Successfully!!!';
    RAISE NOTICE '-------------------------------------------------------';
    
    -- ========================================================================
    -- Summary & Completion
    -- ========================================================================
    RAISE NOTICE '=======================================================';
    RAISE NOTICE 'Silver Layer Loading Completed Successfully';
    RAISE NOTICE '=======================================================';
    RAISE NOTICE '>> Total Load Duration: %', (clock_timestamp() - batch_start_time);
    RAISE NOTICE '-------------------------------------------------------';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '=======================================================';
        RAISE NOTICE 'ERROR OCCURRED DURING LOADING SILVER LAYER';
        RAISE NOTICE 'Error Message: %', SQLERRM;
        RAISE NOTICE 'Error State:   %', SQLSTATE;
        RAISE NOTICE '=======================================================';
        RAISE;
END;
$$;
