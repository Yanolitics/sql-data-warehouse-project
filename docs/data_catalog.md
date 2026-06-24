# Gold Layer (Data Mart) - Data Catalog

This data catalog provides a comprehensive structural mapping of the conformed **Gold Layer Data Mart**. The architecture follows a classic Star Schema design optimized for analytics, business intelligence (BI) modeling, and reporting engines.

---

## 👥 Table: gold.dim_customer
**Table Type:** Dimension Table (Conformed)  
**Description:** Contains master customer profile records. Integrates core customer identities from CRM operations patched with regional and demographic data from ERP source tables.

| Column Name | Column Type | Description |
| :--- | :--- | :--- |
| **customer_key** (PK) | INT | Surrogate Key. Automatically generated unique row identifier for the dimensional model. |
| **customer_id** | INT | Operational customer identifier derived from the source CRM database. |
| **customer_number** |獲 NVARCHAR(50) | Natural business key used to match profile traces across CRM and ERP platforms. |
| **first_name** | NVARCHAR(100) | Standardized and trimmed first name of the customer. |
| **last_name** | NVARCHAR(100) | Standardized and trimmed last name of the customer. |
| **country** | NVARCHAR(100) | Fully resolved regional country classification mapping from the ERP system. |
| **marital_status** | NVARCHAR(20) | Unified marital state attribute descriptive strings (`Single`, `Married`, or `N/A`). |
| **gender** | NVARCHAR(20) | Consolidated gender metric (`Male`, `Female`, or `N/A`) leveraging source fallback prioritization rule. |
| **birthdate** | DATE | Historic calendar date of birth for profiling and generation demographics. |
| **create_date** | DATETIME | Original operational baseline record timestamp creation date tracked from the CRM system. |

---

## 📦 Table: gold.dim_product
**Table Type:** Dimension Table (Conformed)  
**Description:** Contains structural product definitions, catalogs, and pricing baselines. Filters history logs dynamically to isolate the current operational state of products.

| Column Name | Column Type | Description |
| :--- | :--- | :--- |
| **product_key** (PK) | INT | Surrogate Key. Automatically generated unique row identifier for the dimensional model. |
| **product_id** | INT | Operational item identifier derived from the source CRM database. |
| **product_number** | NVARCHAR(50) | Cleaned natural business identifier for the specific product SKU. |
| **category_id** | NVARCHAR(50) | Structured internal grouping reference alphanumeric matrix code tracking product tier trees. |
| **product_name** | NVARCHAR(100) | Cleaned descriptive retail presentation title naming of the item asset. |
| **category** | NVARCHAR(50) | High-level business core inventory category group name derived from ERP classifications. |
| **subcategory** | NVARCHAR(50) | Granular inventory item line classification subclass level mapped from ERP profiles. |
| **product_line** | NVARCHAR(50) | Evaluated and formatted production context focus tracking (`Mountain`, `Road`, `Touring`, etc.). |
| **maintenance** | NVARCHAR(50) | Operational parameters detailing diagnostic care or standard warranty rules for the item asset. |
| **cost** | DECIMAL(18,4) | Standard internal wholesale financial accounting cost baseline value assigned to the item block. |
| **start_date** | DATE | Dynamic timeline stamp tracking when this version of the product became current. |

---

## 💰 Table: gold.fact_sales
**Table Type:** Central Fact Table  
**Description:** Captures line-level operational transactional sales rows. Houses numeric performance variables and points outward to dimensions using surrogate relationships.

| Column Name | Column Type | Description |
| :--- | :--- | :--- |
| **order_number** | NVARCHAR(50) | Natural transactional receipt operational booking ID tracking single checkout groupings. |
| **product_key** (FK) | INT | Relational surrogate routing vector map joining tracking context directly inside `gold.dim_product`. |
| **customer_key** (FK) | INT | Relational surrogate routing vector map joining tracking context directly inside `gold.dim_customer`. |
| **order_date** | DATE | Calendar date defining exactly when the financial purchase exchange agreement was locked. |
| **shipping_date** | DATE | Safe transactional log timestamp tracking when distribution logistics finalized freight dispatching. |
| **due_date** | DATE | Expected transaction fulfillment target date or final invoicing accounts-receivable cut-off boundary. |
| **sales_amount** | DECIMAL(18,4) | Cleansed net gross transaction line level currency value (Guaranteed to reconcile to $\text{Quantity} \times \text{Price}$). |
| **quantity** | INT | Aggregatable metric total piece count volume size shipped inside the specific purchase unit record. |
| **price** | DECIMAL(18,4) | Reconciled uniform structural unit retail valuation currency pricing set per unit item piece. |
