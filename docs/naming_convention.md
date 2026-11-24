# 📐 Data Warehouse Naming Conventions & Design Standards

- **Project**: SQL Data Warehouse (Sales & Customer Analytics)
- **Author**: Prayash Sapkota
- **Scope**: Enterprise Architecture Standards (Bronze, Silver, Gold)

---

## 1. Core Principles

The naming conventions and architectural standards in this project adhere to four foundational principles:
1. **Consistency**: A single, uniform casing and structural pattern applied across all database objects, columns, and files.
2. **Self-Documenting**: Object and column names explicitly convey their technical role, grain, and business meaning without requiring external decoding.
3. **Layer Differentiation**: Architectural tier (Bronze, Silver, Gold) is instantly identifiable from object prefixes and schema names.
4. **BI & Analytics Readiness**: Gold layer naming eliminates technical acronyms and source-system abbreviations in favor of intuitive, business-friendly terminology.

---

## 2. General Casing & Format Standards

| Object Type | Standard Format | Example | Anti-Pattern to Avoid |
| :--- | :--- | :--- | :--- |
| **Schemas** | Lowercase `snake_case` | `bronze`, `silver`, `gold` | `BronzeLayer`, `SILVER` |
| **Tables / Views** | Lowercase `snake_case` | `crm_cust_info`, `fact_sales` | `CRM_CustInfo`, `FactSales` |
| **Columns** | Lowercase `snake_case` | `customer_key`, `sales_amount` | `CustomerKey`, `SalesAmt` |
| **Stored Procedures** | Lowercase with verb prefix | `load_bronze()`, `load_silver()` | `sp_load_data`, `ProcBronze` |
| **SQL Script Files** | Lowercase `snake_case` with prefix | `ddl_silver.sql`, `proc_load_silver.sql` | `SilverScript.sql`, `procLoad.sql` |
| **Documentation** | Lowercase `snake_case` with `.md` | `project_plan.md`, `data_catalog.md` | `ProjectPlan.docx`, `CATALOG.MD` |

---

## 3. Schema & Table Naming Architecture

### 3.1 Bronze Layer (Raw Staging)
- **Schema**: `bronze`
- **Naming Pattern**: `<source_system>_<source_entity>`
- **Purpose**: Mirrors source operational extracts while preserving source system identity.
  - Examples: `bronze.crm_cust_info`, `bronze.crm_sales_details`, `bronze.erp_loc_a101`

### 3.2 Silver Layer (Cleansed & Standardized)
- **Schema**: `silver`
- **Naming Pattern**: `<source_system>_<source_entity>`
- **Purpose**: Maintains source traceability and 1-to-1 lineage with Bronze while storing typed, deduplicated, and cleansed data.
  - Examples: `silver.crm_cust_info`, `silver.crm_prd_info`, `silver.erp_px_cat_g1v2`

### 3.3 Gold Layer (Star Schema / Presentation)
- **Schema**: `gold`
- **Prefix Standard**:
  - **Dimension Tables/Views**: `dim_<entity>` (e.g., `gold.dim_customers`, `gold.dim_products`, `gold.dim_date`)
  - **Fact Tables/Views**: `fact_<business_event>` (e.g., `gold.fact_sales`)
- **Purpose**: Implements Kimball Dimensional Modeling optimized for business intelligence, reporting, and ad-hoc analytics.

---

## 4. Column Naming Standards

### 4.1 Key Identifiers

| Key Type | Suffix Standard | Definition & Architectural Usage | Gold Layer Example |
| :--- | :---: | :--- | :--- |
| **Surrogate Key** | `_key` | System-generated sequential integer (`BIGINT`/`INT`) serving as the primary or foreign key in the Star Schema. Completely decouples the warehouse from source keys. | `customer_key`, `product_key` |
| **Natural / Source Key** | `_id` | Original numeric or integer identifier assigned by the operational source system. Retained as an attribute for lineage. | `customer_id`, `product_id`, `category_id` |
| **Business Code / Number** | `_number` | Alphanumeric business identifier used by operations or customers (e.g., invoice numbers, SKU codes). | `order_number`, `customer_number`, `product_number` |

### 4.2 Temporal & Date Fields

All calendar and timestamp attributes strictly use the `_date` or `_time` suffix:
- **`order_date`**: The date when a sales transaction was authorized.
- **`shipping_date`**: The date when an order departed the warehouse.
- **`due_date`**: The expected delivery milestone date.
- **`birth_date`**: Customer date of birth.
- **`create_date`**: Account creation date in the source CRM.
- **`start_date`**: Effective start date for slowly changing dimension records.
- **`dwh_create_date`**: System metadata timestamp indicating when the row was loaded into the warehouse table.

### 4.3 Quantitative Measures (Fact Attributes)

Measures in fact tables must explicitly describe the metric being quantified:
- **Additive Monetary Values**: Use clear currency/amount names (e.g., `sales_amount`, `cost`, `price`).
- **Counts / Discrete Volumes**: Use `quantity` or `<item>_count` (e.g., `quantity`).
- Avoid ambiguous abbreviations like `amt`, `qty`, `tot_val`.

### 4.4 Descriptive Attributes (Dimension Fields)

- **Personal Information**: `first_name`, `last_name`, `gender`, `marital_status`.
- **Geographic Information**: Standard full noun names (e.g., `country`, `state`, `city`).
- **Product Hierarchy**: `category`, `subcategory`, `product_line`, `product_name`.
- **Status / Flags**: Use affirmative nouns or descriptors (e.g., `maintenance` with standardized domain values `'Yes'` / `'No'`).

---

## 5. Script & File Organization

The repository enforces a structured directory hierarchy matching the pipeline flow:

```text
data-warehouse-project-sql/
├── datasets/                 # Raw source CSV extracts
│   ├── source_crm/           # Operational CRM exports
│   └── source_erp/           # Operational ERP exports
├── sql/                      # All database DDL and stored procedures
│   ├── init_database.sql     # Database instance & schema initialization
│   ├── bronze/               # Bronze layer scripts
│   │   ├── ddl_bronze.sql    # Table DDL
│   │   └── proc_load_bronze.sql # Ingestion procedure
│   ├── silver/               # Silver layer scripts
│   │   ├── ddl_silver.sql    # Cleansed table DDL
│   │   └── proc_load_silver.sql # Transformation procedure
│   └── gold/                 # Gold layer scripts
│       ├── ddl_gold.sql      # Star schema view definitions
├── tests/                    # Data quality assertion suites
│   ├── quality_checks_silver.sql # Silver integrity tests
│   └── quality_checks_gold.sql   # Gold dimensional & reconciliation tests
└── docs/                     # Technical specifications & documentation
    ├── project_plan.md       # Master project plan & tracking
    ├── naming_convention.md  # Naming standards & design rules
    ├── data_catalog.md       # Gold layer data dictionary
    └── diagrams/             # Draw.io architectural assets
```

---

## 6. Stored Procedure & Routine Conventions

- **Procedure Syntax**: `CREATE OR REPLACE PROCEDURE <schema>.load_<schema>()`
  - Bronze: `bronze.load_bronze()`
  - Silver: `silver.load_silver()`
- **Procedural Language**: `LANGUAGE plpgsql`
- **Transaction Safety**: Every procedure must encapsulate work inside a `BEGIN ... EXCEPTION ... END;` block to ensure transactional integrity and automated rollbacks on runtime exceptions.
- **Auditing & Logging**: Standardized `RAISE NOTICE` banners report individual table durations and total batch elapsed time using `clock_timestamp()`.
