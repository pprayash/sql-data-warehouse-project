# 📋 Project Plan: SQL Data Warehouse (Sales & Customer Analytics)

- **Author**: Prayash Sapkota
- **Status**: In Progress
- **Architecture**: Medallion (Bronze → Silver → Gold)
- **Tech Stack**: SQL (PostgreSQL), Git, GitHub

---

## 1. Project Overview & Scope

### 1.1 Objective
To build an end-to-end modern Data Warehouse that integrates disparate operational data from customer relationship management (CRM) and enterprise resource planning (ERP) systems into a centralized Star Schema optimized for sales reporting and business intelligence.

### 1.2 Boundaries
- **In-Scope**:
  - Ingestion of raw operational source extracts into Bronze staging tables.
  - Data cleansing, standardization, deduplication, and referential validation in the Silver layer.
  - Star Schema dimensional modeling in the Gold layer (Facts & Dimensions).
  - Automated data quality testing, procedure-based pipeline orchestration, and technical documentation.
- **Out-of-Scope**:
  - Real-time streaming ingestion (batch ELT/ETL processing only).
  - End-user visualization dashboard implementation (focused on warehouse data tier).

---

## 2. Requirement Analysis

### 2.1 Key Business Questions & Analytical Goals
1. **Sales Performance**: Total sales revenue, transaction volume, and product profitability across geographic locations and time periods to identify top and bottom performers.
2. **Customer Segmentation**: Sales contribution and purchasing behavior broken down by customer demographic segments (age cohorts, gender, marital status) across regions.
3. **Product Hierarchy Analytics**: Revenue and volume distribution across product categories and subcategories over time.

### 2.2 Source Data Inventory
| Source System | File Name | Grain (What 1 row represents) | Format | Estimated Volume |
| :--- | :--- | :--- | :---: | ---: |
| **CRM** | `cust_info.csv` | 1 customer profile record | CSV | ~10,000–20,000 |
| **CRM** | `prd_info.csv` | 1 product catalog entry | CSV | ~500 |
| **CRM** | `sales_details.csv` | 1 order line-item transaction | CSV | ~60,000 |
| **ERP** | `loc_a101.csv` | 1 customer geographic location | CSV | ~10,000–20,000 |
| **ERP** | `cust_az12.csv` | 1 customer demographic profile | CSV | ~10,000–20,000 |
| **ERP** | `px_cat_g1v2.csv` | 1 product category / subcategory definition | CSV | ~50 |

### 2.3 Data Quality Challenges & Profiling Strategy
Operational extracts from legacy systems inherently contain anomalies that must be systematically remediated in the Silver layer:
- **Identifier Discrepancies**: Inconsistent formatting, system-specific prefixes, and delimiters that obstruct entity resolution across systems.
- **Duplicate Records**: Redundant entries sharing business keys due to asynchronous source extracts or re-transmissions.
- **Categorical Drift**: Unstandardized codes, abbreviations, case variations, and unwanted whitespace in descriptive fields.
- **Temporal & Boundary Anomalies**: Out-of-range dates, chronological inversions (e.g., shipping date preceding order date), and impossible birthdates.
- **Derived Metric Inconsistencies**: Financial and quantity values requiring mathematical reconciliation and non-negative constraints.

### 2.4 Transformation & Standardization Standards
- **Key Harmonization**: Normalize identifier formats across source systems to enable cross-system joins (strip extraneous prefixes, delimiters, and whitespace).
- **Domain Standardization**: Map divergent operational codes (e.g., gender, marital status, country designations) into unified canonical reference values, establishing standard fallback handling (`'n/a'`) for missing or unmapped values.
- **Temporal & Type Casting**: Convert raw integer/text representations of dates and numeric fields into native SQL `DATE` and numeric types with strict boundary validation.
- **Hierarchical Decomposition**: Parse composite operational identifiers into structured dimensions (e.g., decomposing compound product identifiers into distinct category and product components).
- **Mathematical Integrity**: Enforce consistency on financial and operational metrics (e.g., ensuring sales revenue equals quantity multiplied by unit price).

### 2.5 Naming Conventions
- **Casing**: All table and column names strictly use lowercase `snake_case`.
- **Keys**: 
  - Natural / Source IDs use suffix `_id` (e.g., `customer_id`).
  - Warehouse surrogate keys use suffix `_key` (e.g., `customer_key`).
- **Layer Standards**:
  - `bronze`: Staging tables mirroring source schema names.
  - `silver`: Cleansed tables with source prefix retained for lineage traceability.
  - `gold`: Star schema artifacts prefixed with `dim_` (Dimensions) or `fact_` (Facts).

---

## 3. Architecture & Data Modeling

### 3.1 Pipeline Flow
```mermaid
flowchart LR
    Source[(Raw CSVs)] -->|Bulk Load| Bronze[(Bronze: Raw Tables)]
    Bronze -->|Clean & Deduplicate| Silver[(Silver: Cleaned Tables)]
    Silver -->|Star Schema Modeling| Gold[(Gold: Fact & Dims)]
```

### 3.2 Target Star Schema (Gold Layer)
The presentation layer implements a Kimball Star Schema architecture:
- **Fact Tables**: Granular transactional event records containing surrogate foreign keys to associated dimensions, along with quantitative additive metrics (quantities, pricing, financial totals).
- **Dimension Tables**: Conformed, context-rich master entity descriptors (customer demographics and geography, product catalog hierarchies, and enterprise calendar dimensions) providing filtering and grouping capabilities for analytical reporting.

---

## 4. Data Quality & Testing Strategy

A comprehensive quality assurance framework is implemented across the pipeline. All quality checks are executed as assertion queries where any returned record represents a defect (target expectation: **0 rows**).

### 4.1 Testing Dimensions & Framework

| Testing Dimension | Objective | Implementation Scope (Silver Layer) | Acceptance Target |
| :--- | :--- | :--- | :---: |
| **Uniqueness & Grain** | Verify primary keys and composite grains uniquely identify records with zero duplicate entries. | Partitioned deduplication on customer IDs, product IDs, category IDs, and sales transaction line items. | 0 duplicates |
| **Completeness & Nullability** | Ensure mandatory business keys and critical attributes contain no missing or empty values. | Null and blank string validation on primary keys, order numbers, and join attributes across all tables. | 0 null/blank keys |
| **Referential Integrity** | Validate entity resolution and foreign key linkages between operational systems (CRM & ERP). | Cross-source reconciliation between CRM customer profiles, ERP demographics, and ERP location records. | 100% key match |
| **Domain Validity & Standardization** | Enforce unified taxonomies across demographic, geographic, and status attributes. | Standardization of gender codes, marital statuses, country naming conventions, and maintenance indicators. | 0 unmapped values |
| **Sanity & Business Math** | Guarantee mathematical consistency and positive numeric ranges for financial calculations. | Validation that transaction sales totals equal quantity multiplied by unit price; non-negative cost and price constraints. | 0 math violations |
| **Chronological Consistency** | Verify temporal integrity across business event lifecycles. | Chronological validation ensuring order dates precede or equal ship and due dates; plausible birthdate ranges. | 0 chronological errors |
| **Pipeline Idempotency** | Guarantee automated reload pipelines execute deterministically without row inflation. | Transaction-safe truncation and execution duration logging in stored procedures (`load_bronze`, `load_silver`). | Deterministic row counts |

### 4.2 Silver Layer Validation Results
All 6 Silver tables have undergone automated testing via `tests/quality_checks_silver.sql` and achieved full compliance:
- **`silver.crm_cust_info`**: 18,484 rows validated; 10 duplicate customer records resolved; clean whitespace and normalized attributes.
- **`silver.crm_prd_info`**: 397 rows validated; 0 null/negative costs; category identifiers extracted; SCD Type-2 dates synchronized.
- **`silver.crm_sales_details`**: 60,398 rows validated; 100% mathematical consistency on sales totals; 0 chronological date inversions.
- **`silver.erp_cust_az12`**: 18,484 rows validated; source identifier prefixes stripped; future/corrupt birthdates nulled; standardized gender.
- **`silver.erp_loc_a101`**: 18,484 rows validated; source formatting resolved; country names standardized with 100% CRM key alignment.
- **`silver.erp_px_cat_g1v2`**: 37 rows validated; category and subcategory hierarchies validated; maintenance flags normalized.

---

## 5. Risks & Mitigations
| Risk | Impact | Mitigation Strategy |
| :--- | :--- | :--- |
| Schema changes or corrupt formats in raw sources | High | Ingest raw files into Bronze using relaxed data types to prevent pipeline failure, enforcing validation in Silver. |
| Duplicate rows from pipeline re-runs | High | Use idempotent stored procedures with atomic truncation and transaction boundaries. |
| Referential mismatch between operational systems | High | Establish standardized entity resolution logic in Silver; map unmatched keys to unknown dimension members in Gold. |

---

## 6. Execution Roadmap & Milestones

### Phase 1: Project Planning & Architecture
- [x] Initialize Git repository and GitHub remote.
- [x] Create project directory structure (`datasets/`, `sql/`, `tests/`, `docs/`).
- [x] Inspect raw CRM & ERP datasets (identify grain, keys, and volumes).
- [x] Formulate core business questions & analytical KPIs.
- [x] Define naming conventions and transformation standards.
- [x] Document the master project plan (`docs/project_plan.md`).
- [x] Design high-level Medallion Architecture diagram in Draw.io (`docs/diagrams/High-level-Medallion-Architecture.jpg`).

### Phase 2: Environment & Database Setup
- [x] Install / Connect to PostgreSQL database engine.
- [x] Write script to initialize database schemas (`bronze`, `silver`, `gold`).
- [x] Configure database users, permissions, and DBeaver connections.

### Phase 3: Bronze Layer (Raw Ingestion)
- [x] Write DDL scripts for raw staging tables (`sql/bronze/ddl_bronze.sql`).
- [x] Write bulk-load stored procedure (`sql/bronze/proc_load_bronze.sql`).
- [x] Verify raw row counts match CSV source files.
- [x] Design detailed Data Flow diagram of bronze layer in Draw.io (`docs/diagrams/Data-Flow-Diagram.drawio.png`).

### Phase 4: Silver Layer (Transformation & Cleansing)
- [x] Design Data Integration Diagram in Draw.io (`docs/diagrams/Data-Integration-Diagram.drawio.png`).
- [x] Profile Bronze tables and establish data cleansing rules.
- [x] Write DDL scripts for silver tables (`sql/silver/ddl_silver.sql`).
- [x] Implement transformation, standardization, and deduplication logic.
- [x] Write stored procedure to populate silver layer (`sql/silver/proc_load_silver.sql`).
- [x] Create automated data quality validation suite (`tests/quality_checks_silver.sql`).
- [x] Design detailed Data Flow diagram of silver layer in Draw.io (`docs/diagrams/Data-Flow-Diagram.drawio.png`).

### Phase 5: Gold Layer (Dimensional Modeling & Analytics)
- [ ] Design dimensional models following Kimball Star Schema methodology.
- [ ] Implement surrogate key generation for dimension tables.
- [ ] Build conformed dimension tables consolidating attributes across sources.
- [ ] Build centralized fact tables with foreign key relationships and metrics.
- [ ] Create analytical reporting views.

### Phase 6: Testing & Acceptance Criteria
- [ ] Uniqueness Test (primary keys and grain integrity).
- [ ] Completeness Test (nullability constraints on critical keys).
- [ ] Referential Integrity Test (foreign keys and cross-table linkages).
- [ ] Domain Validity Test (standardized categories and status flags).
- [ ] Sanity & Business Math Test (calculation consistency and positive bounds).
- [ ] Chronological Consistency Test (temporal event ordering).
- [ ] Pipeline Idempotency Test (repeatable executions without data inflation).
