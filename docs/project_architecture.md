# Project Architecture

## Overview

This project implements an end-to-end Medallion Architecture (Bronze -> Silver -> Gold) on Databricks Community Edition with Unity Catalog, connected to a local dbt project for data transformation and Python notebooks for advanced analytics.

---

## System Architecture

```
DATA SOURCES
  UCI Online Retail CSV
  - ISO-8859-1 encoded, dd-MM-yyyy HH:mm date format
  - 541,909 rows, 8 columns
  - Stored in: /Volumes/customer_churn_project/bronze/raw_files/

BRONZE LAYER (Raw)
  Databricks Notebook: PySpark Ingestion
  - bronze.online_retail          <- spark.read.format("csv")
  - bronze.customers_simulated    <- Subscription simulation (PySpark)

  Simulation Logic:
  - monthly_fee: Derived from spend percentile tiers
  - churn_label: 1 if recency > 90 days, else 0
  - tiers: Basic / Standard / Premium / Enterprise

dbt (Local -> Databricks)
  customer_churn_dbt
  - profile: databricks
  - catalog: customer_churn_project

SILVER LAYER (Cleaned)
  silver.stg_transactions
  - EDA-informed filters applied:
    * CustomerID IS NOT NULL          (removed 135,080 rows / 24.9%)
    * InvoiceNo NOT LIKE 'C%'         (removed 9,288 cancellations)
    * Quantity > 0                     (removed 10,624 returns)
    * UnitPrice >= 0.01               (removed 2,517 free items + 4 micro)
    * DISTINCT                        (removed 5,268 duplicates)
    * try_to_timestamp parsing         (dd-MM-yyyy HH:mm format)
  - Engineered: line_total = Quantity * UnitPrice
  - Flags: is_extreme_quantity, is_extreme_price, is_uk_customer

  silver.stg_customers
  - Standardized from bronze.customers_simulated
  - Minimal transformation, type casting

GOLD LAYER (Business Marts)
  gold.mart_customer_segments
  - RFM Scoring (Recency, Frequency, Monetary)
  - NTILE(5) quintiles for R, F, M
  - Business segments: Champions, Loyal, New, Potential, At Risk, Cannot Lose Them, Lost, Others
  - Business priority tiers: P1-P5
  - is_whale flag (top 1% spenders)

  gold.mart_clv_projections
  - lifetimes library format (BG/NBD + Gamma-Gamma inputs)
  - frequency = repeat purchases (count - 1)
  - recency = days between first and last purchase
  - T = days between first purchase and observation end
  - monetary_value = avg of repeat purchases only

  gold.mart_churn_risk
  - 16 ML-ready features
  - Engineered ratios to avoid multicollinearity
  - Engagement score composite
  - Risk flags: is_inactive_60d, is_inactive_90d, is_whale
  - Tier encoding for ML models

  Enriched Tables (Post-Modeling):
  - gold.mart_customer_segments_enriched  <- + K-Means clusters
  - gold.mart_clv_projections_enriched    <- + CLV predictions
  - gold.mart_churn_risk_scored           <- + churn risk scores

DATA SCIENCE (Databricks Notebooks)
  Notebook 1: RFM K-Means Clustering
  - Input: gold.mart_customer_segments
  - Log-transform + StandardScaler
  - K-Means (K=4, silhouette 0.380)
  - Segments: Lost/Dormant (53.7%), Average (33.4%), At Risk (12.9%)
  - Output: gold.mart_customer_segments_enriched

  Notebook 2: CLV Projection
  - Input: gold.mart_clv_projections
  - Method: Robust heuristic (AOV x Freq/Month x 12)
  - BG/NBD attempted but failed convergence (extreme time scales)
  - Total 12-month CLV: GBP 7.7M | Avg: GBP 1,805
  - Top 10% = 42.9% of total CLV

  Notebook 3: Churn Prediction
  - Input: gold.mart_churn_risk
  - Logistic Regression (Primary): ROC-AUC 0.775
  - Random Forest (Benchmark): ROC-AUC 0.781
  - Target leakage caught & fixed (removed recency_days)
  - 1,841 at-risk customers identified
  - Revenue at risk: GBP 423K/year

BI & VISUALIZATION
  Power BI / Tableau (planned)
  - Direct connection to gold.* tables via Databricks connector

  Local Charts (outputs/charts/)
  - null_percentage, distributions, monthly volume, countries
  - correlation_matrix, rfm clusters, clv analysis, churn comparison
```

---

## Tech Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Compute | Databricks Community Edition | Spark processing, Unity Catalog |
| Storage | Unity Catalog Volumes | Raw file ingestion (DBFS disabled) |
| Transformation | dbt-core + dbt-databricks | Medallion architecture, tests, docs |
| Languages | PySpark | Data engineering (Bronze ingestion) |
| | Python 3.11 | Data science modeling |
| | SQL | dbt models |
| Libraries | scikit-learn | K-Means, Logistic Regression, Random Forest |
| | lifetimes | BG/NBD + Gamma-Gamma (attempted) |
| | pandas, numpy, matplotlib, seaborn | EDA & visualization |
| Virtual Envs | uv | dbt venv + datascience venv (isolated) |
| Version Control | Git + GitHub | Portfolio hosting |
| BI | Power BI (planned) | Executive dashboards |

---

## Data Flow Summary

```
Raw CSV (541K rows)
    -> PySpark ingestion -> bronze.online_retail (541K)
    -> dbt Silver cleaning -> silver.stg_transactions (~392K)
    -> dbt Gold aggregation -> gold.mart_* (3 marts)
    -> Python modeling -> enriched tables + visualizations
    -> Power BI -> stakeholder dashboards
```

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Unity Catalog over DBFS | DBFS disabled in Community Edition; UC Volumes are the native path |
| PySpark for ingestion | Pandas cannot read from UC Volumes directly |
| CSV over XLSX | Avoids openpyxl dependency issues and Apache Arrow crashes |
| dbt for transformations | Version-controlled SQL, automated testing, documentation generation |
| Heuristic CLV | BG/NBD failed convergence due to extreme dataset time scales; documented fallback |
| Target leakage fix | Removed recency_days from churn model (it was the churn definition) |
| Separate venvs | Prevents dbt-databricks from conflicting with scikit-learn dependencies |

---

## Environments

### Databricks
- Catalog: customer_churn_project
- Schemas: bronze, silver, gold
- Volume: bronze.raw_files

### Local (Windows)
- Project Root: D:\Customer Churn Project\
- dbt Project: D:\Customer Churn Project\dbt\customer_churn_dbt\
- Profiles: C:\Users\HP\.dbt\profiles.yml
- Virtual Envs: venvs\dbt\ (dbt-databricks) | venvs\datascience\ (scikit-learn)

---

## dbt Models & Tests

| Model | Layer | Tests | Purpose |
|-------|-------|-------|---------|
| stg_transactions | Silver | not_null, accepted_range, uniqueness | Clean transaction data |
| stg_customers | Silver | not_null, unique, accepted_values | Clean customer profiles |
| mart_customer_segments | Gold | not_null, unique, range checks, accepted_values | RFM segmentation |
| mart_clv_projections | Gold | not_null, unique, range checks | CLV model inputs |
| mart_churn_risk | Gold | not_null, unique, range checks, accepted_values | ML features |

Total: 57 automated tests (55 passed, 2 caught edge cases -> fixed)
