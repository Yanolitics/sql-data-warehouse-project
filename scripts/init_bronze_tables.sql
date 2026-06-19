-- ====================================================================
-- Project: Data Warehouse - Bronze Layer (CRM Ingestion)
-- Developer: Yanolitics
-- Purpose: Creates raw landing tables for CRM source data.
-- WARNING: Running this script drops existing tables and permanently 
--          deletes all data within them. Dev use only!
-- ====================================================================

USE DataWarehouse;
GO

-- ─── 1. CUSTOMER INFO TABLE ──────────────────────────────────────────

IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_cust_info;
GO

CREATE TABLE bronze.crm_cust_info (
    cst_id             INT,
    cst_key            NVARCHAR(50),
    cst_firstname      NVARCHAR(50),
    cst_lastname       NVARCHAR(50),
    cst_marital_status NVARCHAR(15),
    cst_gndr           NVARCHAR(15),
    cst_create_date    DATE
);
GO

-- ─── 2. PRODUCT INFO TABLE ───────────────────────────────────────────

IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_prd_info;
GO

CREATE TABLE bronze.crm_prd_info (
    prd_id       INT,
    prd_key      NVARCHAR(50),
    prd_nm       NVARCHAR(50),
    prd_cost     NVARCHAR(50), -- Kept as NVARCHAR to prevent raw loading failures
    prd_line     NVARCHAR(50),
    prd_start_dt DATE,
    prd_end_dt   DATE
);
GO

-- ─── 3. SALES DETAILS TABLE ──────────────────────────────────────────

IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE bronze.crm_sales_details;
GO

CREATE TABLE bronze.crm_sales_details (
    sls_ord_num  NVARCHAR(50),
    sls_prd_key  NVARCHAR(50),
    sls_cust_id  INT,
    sls_order_dt DATE,
    sls_ship_dt  DATE,
    sls_due_dt   DATE,
    sls_sales    NVARCHAR(50), -- Kept as NVARCHAR to safely ingest dirty raw string data
    sls_quantity NVARCHAR(50),
    sls_price    NVARCHAR(50)
);
GO

-- ─── VERIFICATION AUDIT ──────────────────────────────────────────────

SELECT 
    s.name AS schema_name, 
    t.name AS table_name,
    t.create_date
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'bronze'
ORDER BY table_name;
GO
