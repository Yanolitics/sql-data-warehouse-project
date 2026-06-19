# 🏛️ End-to-End SQL Server Data Warehouse: Medallion Architecture

Welcome to my data warehousing project! This repository contains the complete implementation of a modern, multi-layered data pipeline built entirely within **Microsoft SQL Server**. 

As a self-taught aspiring data engineer operating under the moniker **Yanolitics**, I designed this project to showcase how raw, messy business data can be systematically ingested, sanitized, structured, and served to stakeholders using enterprise-level data design principles.

---

## 🗺️ High-Level Architecture

The pipeline follows a modular Medallion-style architecture (Bronze → Silver → Gold) to ensure data lineage, scalability, and strict governance. The entire design layout is detailed in the file **DWH Data Architecture.png**.

[ SOURCES ]            [ BRONZE ]               [ SILVER ]               [ GOLD ]             [ CONSUME ]
CRM & ERP CSVs  ───>  Raw Data Tables  ───>  Clean/Standardized  ───>  Business-Ready  ───>  Ad-Hoc Queries
(Files in Folders)    (Truncate & Insert)       (Transformations)          (Views)            (SQL Audits)


---

## 🛠️ Pipeline Breakdown

### 1. Sources Layer
*   **Data Origins:** Downstream data originates from core business operational systems: **CRM** (Customer Relationship Management) and **ERP** (Enterprise Resource Planning).
*   **Object Type:** Flat `.csv` files.
*   **Interface:** Files organized systematically within local file systems/folders.

### 2. Data Warehouse: Bronze Layer (Raw Data Area)
*   **Purpose:** Acts as the initial ingestion landing zone. Data is brought in exactly as-is to preserve the original raw history.
*   **Object Type:** Physical Database Tables.
*   **Load Strategy:** Batch processing via Full Load utilizing a `Truncate & Insert` strategy.
*   **Transformations:** **None.** Data is kept completely untouched to allow for full reproducibility if a pipeline fails downstream.
*   **Data Model:** None (As-Is representation of source files).

### 3. Data Warehouse: Silver Layer (Cleaned & Standardized Area)
*   **Purpose:** This is the core engineering layer where raw chaos is whipped into shape. It relies heavily on technical **Data Cleaning & Standardization** to guarantee data integrity.
*   **Object Type:** Physical Database Tables.
*   **Load Strategy:** Batch processing via Full Load using a `Truncate & Insert` mechanism.
*   **Transformations Applied:**
    *   **Data Cleansing:** Handling missing entries, null values, and parsing errors.
    *   **Data Standardization:** Formatting date variations, enforcing strict data types, and stabilizing string values.
    *   **Data Normalization:** Restructuring tables to reduce redundancy and improve dependency alignment.
    *   **Derived Columns & Enrichment:** Generating calculated attributes and joining peripheral details to add contextual depth.
*   **Data Model:** None (Flat, clean, highly-indexed structural staging).

### 4. Data Warehouse: Gold Layer (Business-Ready Area)
*   **Purpose:** The presentation layer optimized for consumption, reporting, and high-performance querying.
*   **Object Type:** **SQL Views** (Virtual tables to ensure zero data redundancy and real-time computation of business metrics).
*   **Load Strategy:** **No Physical Load** (On-the-fly execution via decoupled database views).
*   **Transformations Applied:** High-level data integration, complex analytical aggregations, and strict business logic implementations.
*   **Data Models Supported:**
    *   **Star Schema:** Fully modeled Fact and Dimension tables ready for swift BI analytics.
    *   **Flat Tables:** De-normalized, wide structures for simple reporting.
    *   **Aggregate Tables:** Pre-computed summary data blocks to speed up frequent operational lookups.

### 5. Consume Layer
*   **Purpose:** End-user data exposure.
*   **Access Pattern:** **Ad-Hoc SQL Queries** used for auditing pipeline health, verifying business logic, or fueling business intelligence tools.

---

## ⚡ Tech Stack & Core Concepts Demonstrated

*   **Database Engine:** Microsoft SQL Server (T-SQL)
*   **Data Engineering Framework:** Medallion Architecture (Bronze/Silver/Gold)
*   **Primary Focus:** Complex Data Cleaning, Schema Standardization, and Star Schema Dimensional Modeling.
*   **Architectural Inspiration:** Modeled closely after industry-standard data engineering roadmaps (specifically drawing from the *Data with Baraa* engineering curriculum).

---

## 👨‍💻 About the Developer

I’m Timothy, a former banking documentation analyst who spent three years managing rigid data compliance and structure. I chose to pivot into the tech sector because I love building systems, wrestling with technical tools, and mastering business intelligence. 

I am entirely self-taught through dedicated, project-driven bootcamps and courses. While I am still navigating the earlier stages of my engineering career, I bring an incredibly high tolerance for debugging, a rigorous eye for detail inherited from banking, and a promise to write clean code that minimizes the risk of breaking database production environments.
