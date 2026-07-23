# Project Architecture

## Customer Churn Intelligence Platform

This document describes the actual pipeline as built — no orchestration tools, services, or steps are listed here beyond what is implemented in the current codebase.

---

## 1. High-Level Architecture

```
UCI Online Retail CSV (541,909 rows)
        │
        ▼
Databricks Notebook — Data Ingestion
        │  (reads CSV, writes to Unity Catalog Volume, loads Bronze Delta table)
        ▼
Unity Catalog: customer_churn_project.bronze
   ├── bronze.online_retail            (raw transactions)
   └── bronze.customers_simulated      (customer aggregates + synthetic subscription fields)
        │
        ▼
Databricks Notebook — Raw EDA
   (customer_churn_EDA.ipynb — profiles nulls, duplicates, outliers,
    temporal/geographic bias; findings feed the Silver filter logic below)
        │
        ▼
dbt-core (run locally, connected to the Databricks SQL warehouse)
   ├── models/silver/
   │     ├── stg_transactions.sql   → customer_churn_project.silver.stg_transactions
   │     └── stg_customers.sql      → customer_churn_project.silver.stg_customers
   └── models/gold/
         ├── mart_customer_segments.sql   → customer_churn_project.gold.mart_customer_segments
         ├── mart_clv_projections.sql     → customer_churn_project.gold.mart_clv_projections
         └── mart_churn_risk.sql          → customer_churn_project.gold.mart_churn_risk
        │
        ▼
Databricks Notebooks — Business EDA / Modeling
   ├── 01_rfm_kmeans_clustering.ipynb  → gold.mart_customer_segments_enriched, gold.cluster_mapping
   ├── 02_CLV_churn.ipynb              → gold.mart_clv_projections_enriched
   └── 03_Churn_Prediction.ipynb       → gold.mart_churn_risk_scored
        │
        ▼
Power BI / Interactive Dashboard
   (built directly on the enriched Gold marts)
```

**No orchestration tool (e.g., Airflow, dbt Cloud) is used in this project.** The pipeline is run as a manual sequence: Databricks notebook ingestion → Databricks notebook raw EDA → dbt-core (local) Silver/Gold builds → Databricks notebooks for modeling → BI layer. This is stated explicitly here so the architecture diagram matches what was actually built, not a target-state design.

---

## 2. Medallion Layer Detail

### Bronze (Raw)
- **Storage:** Unity Catalog Volume holds the landed CSV; a Databricks notebook loads it into a Bronze Delta table.
- **Tables:** `bronze.online_retail` (541,909 rows, 8 columns), `bronze.customers_simulated` (customer-level aggregate + synthetic subscription fields).
- **Transformation:** None — this is the raw landed data, used as the dbt `source()` layer (see `sources.yml`).

### Silver (Cleaned)
- **Tool:** dbt-core, materialized as `table` (Delta format, per `dbt_project.yml`).
- **Models:** `stg_transactions.sql`, `stg_customers.sql`.
- **Logic applied (informed directly by the raw EDA notebook):**
  1. Exclude rows with `CustomerID IS NULL` (135,080 rows / 24.93%)
  2. Exclude cancelled orders, `InvoiceNo LIKE 'C%'` (9,288 rows / 1.71%)
  3. Exclude `Quantity ≤ 0` (10,624 rows / 1.96%)
  4. Exclude `UnitPrice < 0.01` (2,517+4 rows — tightened after a dbt test failure caught 4 micro-value rows the manual EDA missed)
  5. Deduplicate exact duplicate rows via `SELECT DISTINCT` (5,268 rows / 0.97%)
  6. Parse `InvoiceDate` from `dd-MM-yyyy HH:mm` using `try_to_timestamp`
  7. Engineer `line_total = ROUND(Quantity × UnitPrice, 2)`
  8. Flag `is_extreme_quantity` (>10,000), `is_extreme_price` (>£5,000), `is_uk_customer`

### Gold (Business Marts)
- **Tool:** dbt-core, materialized as `table`, schema-scoped via `generate_schema_name.sql` macro (uses `target.schema` when no custom schema is set, otherwise the model's declared schema — `silver`/`gold`).
- **Models:**
  - `mart_customer_segments.sql` — RFM scoring via `NTILE(5)` windows, rule-based segment labeling, whale flag at the 99th spend percentile.
  - `mart_clv_projections.sql` — formats recency/frequency/`T`/monetary_value for the `lifetimes` library convention; deliberately anchors `T` to the dataset's own max invoice date rather than `CURRENT_DATE()`.
  - `mart_churn_risk.sql` — joins transaction behavior with the synthetic subscription data; engineers ratio features (`spend_per_transaction`, `items_per_transaction`, `spend_per_product`, `purchase_regularity`) specifically to avoid the 0.92 `total_spend`/`total_items` correlation found in EDA; computes a composite `engagement_score`.

### Modeling Layer (Databricks Notebooks)
- `01_rfm_kmeans_clustering.ipynb` — StandardScaler + log transform → K-Means (K=2–10 tested, K=4 selected) → cluster naming → writes `mart_customer_segments_enriched` and `cluster_mapping`.
- `02_CLV_churn.ipynb` — validates `lifetimes` preconditions → attempts BG/NBD + Gamma-Gamma (fails to converge) → falls back to heuristic CLV → writes `mart_clv_projections_enriched`.
- `03_Churn_Prediction.ipynb` — feature engineering with leakage check → Logistic Regression (primary) + Random Forest (benchmark) → 5-fold CV → risk scoring → writes `mart_churn_risk_scored`.

### BI / Presentation Layer
- Power BI (or an interactive HTML dashboard) reads directly from the three enriched Gold marts. *[Dashboard build in progress — screenshots and interactive file to be added once finalized.]*

---

## 3. Tech Stack

| Layer | Tool | Purpose |
|---|---|---|
| Compute | Databricks (Unity Catalog) | Ingestion, raw EDA, and all modeling notebooks |
| Storage | Unity Catalog Volumes + Delta tables | Raw file landing + Bronze/Silver/Gold tables |
| Transformation | dbt-core (run locally) + `dbt-databricks` adapter | Silver cleaning, Gold mart building, schema tests |
| Languages | SQL (dbt models), Python (notebooks) | Transformation logic and modeling |
| ML / Stats libraries | scikit-learn (`KMeans`, `LogisticRegression`, `RandomForestClassifier`), `lifetimes` (BG/NBD attempt) | Segmentation and churn/CLV modeling |
| Data libraries | pandas, numpy | Notebook-side data handling |
| Visualization | matplotlib, seaborn | EDA and model-output charts |
| Version control | Git + GitHub | Portfolio hosting |
| BI | Power BI / interactive HTML dashboard | Stakeholder-facing views |

**dbt project configuration** (from `dbt_project.yml`, reproduced exactly):

```yaml
name: 'customer_churn_dbt'
version: '1.0.0'
config-version: 2

profile: 'customer_churn_dbt'

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

target-path: "target"
clean-targets:
  - "target"
  - "dbt_packages"

models:
  customer_churn_dbt:
    +materialized: table
    +file_format: delta
    silver:
      +schema: silver
    gold:
      +schema: gold
```

> **Note on versions:** `dbt_project.yml` does not pin a `require-dbt-version`, and the exact `dbt-core`/`dbt-databricks` package versions used are not recorded elsewhere in the project artifacts available for this documentation. Stating this directly rather than guessing a version number.

---

## 4. Repository Structure

```
customer-churn-intelligence/
├── dbt_transformation/customer_churn_dbt/
│   ├── models/
│   │   ├── silver/
│   │   │   ├── stg_transactions.sql
│   │   │   └── stg_customers.sql
│   │   └── gold/
│   │       ├── mart_customer_segments.sql
│   │       ├── mart_clv_projections.sql
│   │       └── mart_churn_risk.sql
│   ├── models/sources.yml
│   ├── models/schema.yml
│   ├── macros/generate_schema_name.sql
│   ├── tests/
│   └── dbt_project.yml
├── notebooks/
│   ├── customer_churn_EDA.ipynb              # Phase 1: raw EDA (pre-dbt)
│   ├── 01_rfm_kmeans_clustering.ipynb         # Phase 3: RFM + K-Means
│   ├── 02_CLV_churn.ipynb                     # Phase 3: CLV projection
│   └── 03_Churn_Prediction.ipynb              # Phase 3: churn classification
├── docs/
│   ├── data_dictionary.md
│   ├── data_audit.md
│   ├── data_quality.md
│   └── project_architecture.md
├── outputs/
│   └── charts/
│       ├── 01_null_percentage.png
│       ├── 02_quantity_unitprice_distribution.png
│       ├── 03_transaction_volume_monthly.png
│       ├── 04_top_countries.png
│       ├── 05_customer_spend_frequency.png
│       ├── 06_correlation_matrix.png
│       ├── 07_elbow_silhouette.png
│       ├── 08_rfm_segments.png
│       ├── 09_rfm_3d.png
│       ├── 10_clv_analysis.png
│       ├── 11_roc_pr_curves.png
│       └── 12_churn_drivers.png
├── dashboard/                                  # [in progress]
│   ├── index.html
│   └── screenshots/
├── README.md
```

*(The `airflow_orchestration/` folder referenced in an earlier README draft has been removed from this structure — no Airflow DAG exists in the current build. If orchestration is added later, this document should be updated to match.)*
