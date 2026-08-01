<div align="center">
<img width="1584" height="396" alt="Image" src="https://github.com/user-attachments/assets/2e5917b7-addb-46fc-8897-35ffdf235fbd" />
</div>

<h1 align="center">Customer Churn Analytics</h1>
<h3 align="center">Medallion Pipeline on Databricks · 541K Transactions → 3 Gold Marts · Churn ML with Target Leakage Fix</h3>

<p align="center">
  <img alt="status" src="https://img.shields.io/badge/status-portfolio_project-1E3A5F?style=flat-square">
  <img alt="data" src="https://img.shields.io/badge/data-UCI%20Online%20Retail%20(UK)-8B98AE?style=flat-square">
  <img alt="stack" src="https://img.shields.io/badge/stack-Databricks%20%7C%20dbt--core%20%7C%20Python-1E3A5F?style=flat-square">
  <img alt="scale" src="https://img.shields.io/badge/customers-4%2C338%20%7C%20transactions-541K%20%7C%20predicted%20CLV-%C2%A37.7M-12A879?style=flat-square">
</p>

<p align="center"><b>Saswata Ghosh</b><br>
<a href="https://github.com/Saswataghosh06/Customer-Churn-Analytics">GitHub Repo</a> · <a href="https://www.linkedin.com/in/saswata-ghosh06/">LinkedIn</a> · <a href="saswataghosh2022@gmail.com">Email</a></p>

---

## Overview

A Medallion Architecture data pipeline that ingests 541K raw transactions from the UCI Online Retail dataset into Databricks, cleans and models them into 3 Gold marts using dbt Core, and produces downstream ML outputs — RFM segmentation, CLV projections, and churn risk scores — via Databricks notebooks. The pipeline runs 57 automated dbt data quality tests and includes a documented target leakage fix that was caught and resolved during model development.

On the analytical side, the pipeline surfaced that 53.7% of the customer base is dormant while 12.9% of customers drive 62.8% of revenue, and that 1,841 customers (42.4%) are at Critical or High churn risk, representing £423K in exposed annual revenue. Full business analysis with recommendations → [`docs/business_insights.md`](./docs/business_insights.md)

> **Note:** This project is built on the public UCI Online Retail dataset with synthetic subscription and churn labels. It demonstrates end-to-end pipeline architecture, data quality practices, and modeling methodology.

---

## Architecture

```
Raw CSV (541,909 rows)
   → Databricks notebook ingestion → Bronze Delta tables (Unity Catalog)
   → Databricks notebook raw EDA
   → dbt-core: Silver cleaning models → Gold business marts
   → Databricks notebooks: RFM/K-Means, CLV heuristic, churn classification
   → Enriched Gold marts → Power BI / interactive dashboard
```

| Layer | Purpose | Materialization | Schema |
|---|---|---|---|
| **Bronze** | Raw CSV ingestion into Unity Catalog | Table | `customer_churn_project.bronze` |
| **Silver** | Cleaned and validated transaction + customer data | Table | `customer_churn_project.silver` |
| **Gold** | Business-ready analytical marts | Table | `customer_churn_project.gold` |

**Source datasets (2 Bronze tables):**

| Dataset | Business Entity |
|---|---|
| `online_retail` | Raw UCI transaction data (541,909 rows, 8 columns) |
| `customers_simulated` | Customer-level aggregates with synthetic subscription fields |

**No orchestration tool (e.g., Airflow) is used** — the pipeline currently runs as a manual sequence of Databricks notebooks and dbt commands. This is stated explicitly so the architecture matches what was actually built. Adding orchestration would be the first production change.

---

## Data Model

### Star Schema

<div align="center">
<img width="100%" alt="ERD placeholder — replace with draw.io export" src="https://via.placeholder.com/1200x400/1a1a2e/eee?text=ERD+Diagram+Placeholder%0A2+Staging+Models+%7C+3+Gold+Marts+%7C+3+Enriched+Marts" />
<br><sub>⬆️ Replace this placeholder with your ERD diagram from draw.io</sub>
</div>

### Staging Models

| Model | Primary Key | Grain | Purpose |
|---|---|---|---|
| `stg_transactions` | Composite (`InvoiceNo` + `StockCode`) | One row per transaction line | Cleaned transaction data with EDA-informed filters |
| `stg_customers` | `CustomerID` | One row per customer | Customer aggregates with synthetic subscription fields |

### Gold Marts

| Mart | Primary Key | Grain | Business Domain |
|---|---|---|---|
| `mart_customer_segments` | `CustomerID` | One row per customer | RFM scoring and segmentation |
| `mart_clv_projections` | `CustomerID` | One row per customer (repeat buyers only) | CLV projection inputs |
| `mart_churn_risk` | `CustomerID` | One row per customer | ML-ready churn feature set |

### Enriched Gold Marts (Notebook Outputs)

| Mart | Grain | Purpose |
|---|---|---|
| `mart_customer_segments_enriched` | One row per customer | Adds K-Means cluster assignments |
| `mart_clv_projections_enriched` | One row per customer | Adds CLV heuristic estimates |
| `mart_churn_risk_scored` | One row per customer | Adds churn risk scores and risk tiers |

### Key Modeling Decisions

| Decision | Why |
|---|---|
| **Separate marts for segments, CLV, and churn** | Each mart serves a different downstream consumer (BI dashboard, CLV model, churn model) with different grain and feature requirements. A single mart would duplicate logic and create conflicting grains. |
| **RFM scoring via `NTILE(5)` in SQL** | Keeps segmentation logic in the warehouse where it's testable and auditable, not buried in a notebook. |
| **Ratio features in `mart_churn_risk`** | EDA found `total_spend` and `total_items` correlate at 0.92. Using ratios (`spend_per_transaction`, `items_per_transaction`, `spend_per_product`) avoids multicollinearity in the churn model. |
| **Composite `engagement_score`** | A weighted composite (`0.3×transactions + 0.3×spend/100 + 0.2×unique_products + 0.2×active_months`) that both models rank as a top churn driver. |
| **`recency_days` anchored to dataset end date** | All Gold marts use the dataset's max invoice date (09-Dec-2011) as the reference point, not `CURRENT_DATE()`. This ensures consistent recency calculations across marts. |
| **Synthetic subscription fields** | The UCI dataset has no subscription model. `subscription_tier`, `monthly_fee`, and `churn_label` are synthetic fields layered onto the real transaction data to enable ML feature engineering. |

### Sample Model: `stg_transactions`

```sql
{{ config(materialized='table', schema='silver', tags=['silver', 'transactions']) }}

/*
    EDA-Informed Cleaning Rules Applied:
    1. FILTER: Exclude rows where CustomerID IS NULL (24.93% of raw data)
    2. FILTER: Exclude cancelled orders (InvoiceNo starts with 'C') — 9,288 rows
    3. FILTER: Exclude rows with Quantity <= 0 — 10,624 rows
    4. FILTER: Exclude rows with UnitPrice <= 0 — 2,517 rows
    5. DEDUPLICATE: Remove exact duplicate rows — 5,268 rows
    6. PARSE: InvoiceDate from dd-MM-yyyy HH:mm format (ISO-8859-1 encoding)
    7. ENGINEER: LineTotal = Quantity * UnitPrice
    8. FLAG: Add data quality indicators for downstream auditing
*/

WITH deduplicated AS (
    SELECT DISTINCT
        InvoiceNo, StockCode, Description, Quantity,
        InvoiceDate, UnitPrice, CustomerID, Country
    FROM {{ source('bronze', 'online_retail') }}
),

parsed AS (
    SELECT
        InvoiceNo, StockCode, Description, Quantity,
        try_to_timestamp(InvoiceDate, 'dd-MM-yyyy HH:mm') AS invoice_timestamp,
        UnitPrice, CustomerID, Country
    FROM deduplicated
)

SELECT
    InvoiceNo, StockCode, Description, Quantity,
    invoice_timestamp, UnitPrice, CustomerID, Country,
    ROUND(Quantity * UnitPrice, 2) AS line_total,
    CASE WHEN Quantity > 10000 THEN TRUE ELSE FALSE END AS is_extreme_quantity,
    CASE WHEN UnitPrice > 5000 THEN TRUE ELSE FALSE END AS is_extreme_price,
    CASE WHEN Country = 'United Kingdom' THEN TRUE ELSE FALSE END AS is_uk_customer
FROM parsed
WHERE
    CustomerID IS NOT NULL
    AND InvoiceNo NOT LIKE 'C%'
    AND Quantity > 0
    AND UnitPrice >= 0.01
    AND invoice_timestamp IS NOT NULL
```

### Sample Model: `mart_churn_risk`

```sql
{{ config(materialized='table', schema='gold', tags=['gold', 'churn', 'ml-features']) }}

WITH transaction_features AS (
    SELECT
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS total_transactions,
        ROUND(SUM(line_total), 2) AS total_spend,
        SUM(Quantity) AS total_items,
        COUNT(DISTINCT StockCode) AS unique_products,
        ROUND(AVG(line_total), 2) AS avg_line_value,
        ROUND(SUM(line_total) / COUNT(DISTINCT InvoiceNo), 2) AS avg_order_value,
        DATEDIFF(day, MAX(invoice_timestamp),
            (SELECT MAX(invoice_timestamp) FROM {{ ref('stg_transactions') }}
        )) AS recency_days,
        DATEDIFF(day, MIN(invoice_timestamp), MAX(invoice_timestamp)) AS customer_lifespan_days,
        COUNT(DISTINCT DATE_TRUNC('month', invoice_timestamp)) AS active_months,
        ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT InvoiceNo), 0), 2) AS avg_items_per_order,
        MAX(CASE WHEN line_total > 1000 THEN 1 ELSE 0 END) AS has_high_value_order,
        MAX(CASE WHEN Quantity > 100 THEN 1 ELSE 0 END) AS has_bulk_purchase
    FROM {{ ref('stg_transactions') }}
    GROUP BY CustomerID
),

enriched AS (
    SELECT
        c.CustomerID,
        c.first_purchase_date, c.last_purchase_date, c.tenure_days,
        c.subscription_tier, c.monthly_fee, c.churn_label,
        c.country, c.is_uk_customer,
        t.total_transactions, t.total_spend, t.total_items,
        t.unique_products, t.avg_line_value, t.avg_order_value,
        t.recency_days, t.customer_lifespan_days, t.active_months,
        t.avg_items_per_order, t.has_high_value_order, t.has_bulk_purchase,
        -- Engineered ratios (avoid multicollinearity from EDA: total_spend ↔ total_items = 0.92)
        ROUND(t.total_spend / NULLIF(t.total_transactions, 0), 2) AS spend_per_transaction,
        ROUND(t.total_items * 1.0 / NULLIF(t.total_transactions, 0), 2) AS items_per_transaction,
        ROUND(t.total_spend / NULLIF(t.unique_products, 0), 2) AS spend_per_product,
        ROUND(t.active_months * 1.0 / NULLIF(t.customer_lifespan_days, 0) * 30, 2) AS purchase_regularity,
        CASE 
            WHEN c.subscription_tier = 'Basic' THEN 1
            WHEN c.subscription_tier = 'Standard' THEN 2
            WHEN c.subscription_tier = 'Premium' THEN 3
            WHEN c.subscription_tier = 'Enterprise' THEN 4
        END AS tier_encoded,
        CASE WHEN t.total_spend >= 50000 THEN TRUE ELSE FALSE END AS is_whale,
        CASE WHEN t.recency_days > 90 THEN TRUE ELSE FALSE END AS is_inactive_90d,
        CASE WHEN t.recency_days > 60 THEN TRUE ELSE FALSE END AS is_inactive_60d,
        -- Composite engagement score
        ROUND(
            (t.total_transactions * 0.3) + 
            (t.total_spend / 100 * 0.3) + 
            (t.unique_products * 0.2) + 
            (t.active_months * 0.2), 2
        ) AS engagement_score
    FROM {{ ref('stg_customers') }} c
    LEFT JOIN transaction_features t ON c.CustomerID = t.CustomerID
)

SELECT * FROM enriched
```

---

## Data Quality

57 automated dbt tests across all layers. Full audit → [`docs/data_audit.md`](./docs/data_audit.md)

### Data Cleaning Summary (EDA-Informed)

| Finding | Count | % of Total | Action |
|---|---:|---:|---|
| NULL `CustomerID` | 135,080 | 24.93% | Filtered — unusable for customer analytics |
| Cancelled orders (`Invoice 'C'`) | 9,288 | 1.71% | Filtered — returns distort revenue |
| `Quantity ≤ 0` | 10,624 | 1.96% | Filtered |
| `UnitPrice ≤ 0` | 2,517 | 0.46% | Filtered |
| `UnitPrice < 0.01` (micro-values) | 4 | <0.01% | Filter tightened to ≥ 0.01 after dbt test failure |
| Exact duplicate rows | 5,268 | 0.97% | Deduplicated via `SELECT DISTINCT` |
| Extreme quantity/price outliers | 34 total | <0.01% | Flagged (not removed) in Gold |

### Test Coverage

| Model | Test Types | Key Tests |
|---|---|---|
| `stg_transactions` | `not_null`, range checks | `CustomerID` not null, `Quantity ≥ 1`, `UnitPrice ≥ 0.01`, `line_total ≥ 0.01` |
| `stg_customers` | `not_null`, `unique`, `accepted_values` | `CustomerID` unique, `subscription_tier` in [Basic/Standard/Premium/Enterprise], `churn_label` in [0,1] |
| `mart_customer_segments` | `not_null`, `unique`, `accepted_values`, range | `CustomerID` unique, `r_score`/`f_score`/`m_score` in [1–5], `customer_segment` in 8 valid labels |
| `mart_clv_projections` | `not_null`, `unique`, range | `frequency ≥ 1`, `recency ≥ 0`, `T ≥ 0`, `monetary_value ≥ 0` |
| `mart_churn_risk` | `not_null`, `unique`, `accepted_values`, range | `churn_label` in [0,1], `total_transactions ≥ 1`, `total_spend ≥ 0` |

### Target Leakage Fix

The first churn model scored 100% accuracy and AUC = 1.000. The cause: `recency_days` was included as a feature, but `recency_days > 90` is the literal definition of the `churn_label` target. The model was predicting its own definition.

After removing `recency_days` and `customer_lifespan_days` and rebuilding:

| Model | ROC-AUC | 5-Fold CV ROC-AUC |
|---|---:|---:|
| Logistic Regression | 0.775 | 0.775 (± 0.036) |
| Random Forest | 0.781 | 0.783 (± 0.036) |

This is documented in full in [`docs/data_quality.md`](./docs/data_quality.md) — not as a footnote, but as a first-class finding. Catching this kind of bug in production is the difference between a model that looks perfect and one that actually works.

---

## Pipeline & Orchestration

### Current State

The pipeline runs as a **manual sequence** — no orchestration tool is used:

```
1. Databricks notebook — data ingestion (CSV → Bronze Delta tables)
2. Databricks notebook — raw EDA
3. dbt-core (local) — Silver cleaning + Gold mart building
4. Databricks notebooks — RFM/K-Means, CLV, churn classification
5. Power BI / interactive dashboard
```

### dbt Project Configuration

```yaml
models:
  customer_churn_dbt:
    +materialized: table
    +file_format: delta
    silver:
      +schema: silver
    gold:
      +schema: gold
```

### Technology Stack

| Layer | Tool |
|---|---|
| Compute & Storage | Databricks, Unity Catalog (Delta tables + Volumes) |
| Transformation | dbt-core + `dbt-databricks` adapter |
| Modeling | Python — scikit-learn (K-Means, Logistic Regression, Random Forest), `lifetimes` (attempted) |
| Visualization | matplotlib, seaborn, Power BI |
| Version control | Git + GitHub |

---

## Technical Decisions & Trade-offs

| Decision | Alternative Considered | Why This Choice |
|---|---|---|
| dbt for Silver/Gold transformations | All transformations in notebooks | dbt provides version-controlled, testable, documented SQL. Notebook transformations are invisible to quality checks and hard to audit. |
| RFM scoring in SQL (not Python) | K-Means only for segmentation | SQL-based RFM scoring is auditable and testable. K-Means assigns clusters, but the rule-based segment labels (`Cannot Lose Them`, `At Risk`, etc.) are defined in SQL where they can be validated with `accepted_values` tests. |
| Manual pipeline (no orchestration) | Airflow / GitHub Actions | This project was built to focus on data quality and modeling. Adding orchestration would be the first production change — the pipeline structure is already sequential and would map directly to a DAG. |
| CLV heuristic instead of BG/NBD + Gamma-Gamma | Probabilistic model | BG/NBD + Gamma-Gamma failed to converge on this data's extreme frequency scales. Rather than force an invalid model, the heuristic (AOV × Freq/Month × 12) is documented explicitly as a fallback. |
| Public dataset (UCI Online Retail) | Self-generated synthetic data | The UCI dataset provides realistic transaction patterns. The synthetic subscription fields (`subscription_tier`, `monthly_fee`, `churn_label`) were added to enable ML features the source data doesn't support. |

### What I'd Change in Production

| Area | Current State | Production Change |
|---|---|---|
| **Orchestration** | Manual notebook → dbt → notebook sequence | Add Airflow or GitHub Actions to automate the full pipeline end-to-end |
| **Source freshness** | No freshness monitoring | Add `freshness:` blocks to dbt source YAML with SLA thresholds |
| **Model retraining** | One-time model training | Schedule periodic retraining on a fixed cadence, with drift monitoring |
| **CLV method** | Heuristic (AOV × Freq/Month × 12) | Revisit BG/NBD + Gamma-Gamma with better frequency handling, or use a different probabilistic model |
| **Holdout validation** | No time-split holdout for CLV | Add a time-based holdout to validate CLV predictions against actual future spend |
| **Feature store** | Features computed in `mart_churn_risk` only | Extract features into a reusable feature store for multiple models |

---

## Key Findings

> These findings are produced by the pipeline. Full analysis with evidence, charts, and prioritized recommendations → [`docs/business_insights.md`](./docs/business_insights.md)

| Metric | Value |
|---|---|
| Customers analyzed | 4,338 |
| Valid transactions (post-cleaning) | ~392,000 |
| Total predicted 12-month CLV | **£7,702,146.93** |
| Top 10% of customers' share of predicted CLV | 42.9% (£3,305,578.01) |
| At-risk customers (Critical + High risk) | **1,841 (42.4%)** |
| Revenue at risk | **£422,992.80/year** |
| Best churn model | Random Forest, ROC-AUC 0.781 |
| dbt tests passing | 57/57 |

**Headline finding:** 53.7% of the customer base is dormant, while a 12.9% 'Cannot Lose Them' segment accounts for 62.8% of total customer revenue. Losing the wrong dozen customers matters more than losing the wrong thousand.

### RFM Segmentation — The "Cannot Lose Them" Cluster

<p align="center">
<img width="50%" alt="Image" src="https://github.com/user-attachments/assets/d7bbe943-17d2-4c8c-b1e1-5a22208e6608" />
</p>

| Segment | Customers | Share | Revenue Share |
|---|---:|---:|---:|
| Lost / Dormant | 2,331 | 53.7% | 10.2% |
| Loyal / Average | 1,448 | 33.4% | 27.0% |
| **Cannot Lose Them** | **559** | **12.9%** | **62.8%** |

The "Cannot Lose Them" cluster (orange) sits at high frequency/monetary with rising recency — the classic "was loyal, now fading" pattern.

### Churn Model — After Target Leakage Fix

<p align="center">
<img width="80%" alt="Image" src="https://github.com/user-attachments/assets/6a5abe54-3d8f-4e85-95ee-ccba97c2fd28" />
</p>

| Model | ROC-AUC | 5-Fold CV |
|---|---|---|
| Logistic Regression | 0.775 | 0.775 (± 0.036) |
| Random Forest | 0.781 | 0.783 (± 0.036) |

Both models agree that `engagement_score` and `active_months` are top churn drivers, though they disagree on which is #1. The honest read: low engagement and fewer active months are directionally associated with churn, but the models don't fully agree on which single feature matters most.

---

## Caveats & Assumptions

- **Static dataset (Dec 2010–Dec 2011).** A production system would refresh CLV and churn scores on a schedule; seasonal effects (the November spike) may not generalize to other years.
- **CLV method is a documented heuristic, not the originally-planned probabilistic model.** BG/NBD + Gamma-Gamma failed to converge; the heuristic (AOV × Freq/Month × 12) is industry-standard but assumes stable purchase behavior.
- **Churn definition is a reasonable proxy, not verified ground truth.** `recency_days > 90` is used as the churn label; some customers may have seasonal (not churned) purchase patterns.
- **`subscription_tier` and `monthly_fee` are synthetic fields** layered onto the real UCI transaction data. `churn_label` is generated via `recency_days > 90`.
- **Geographic bias:** ~91–92% of transactions are UK-based. International insights are directional only.
- **Correlation ≠ causation.** The identified churn drivers are associative, from a single trained model snapshot — not causally validated via A/B testing.
- **This is a portfolio case study** built on public data to demonstrate end-to-end pipeline and modeling capability, not a live production system.

---

## Documentation Index

| Document | What's in it |
|---|---|
| [`docs/business_insights.md`](./docs/business_insights.md) | Full business analysis — RFM segmentation, CLV projections, churn drivers, and prioritized recommendations |
| [`docs/data_audit.md`](./docs/data_audit.md) | Raw EDA — nulls, duplicates, outliers, geographic/temporal bias |
| [`docs/data_quality.md`](./docs/data_quality.md) | dbt test results (57/57), model validation, target leakage fix, data governance standards |
| [`docs/data_dictionary.md`](./docs/data_dictionary.md) | Column-level reference across Bronze, Silver, Gold, and enriched marts |
| [`docs/project_architecture.md`](./docs/project_architecture.md) | Full pipeline diagram, tech stack, dbt_project.yml, repository structure |

---

<p align="center"><sub>Built with rigor, documented with honesty. Questions about any specific number or modeling decision — happy to walk through it.</sub></p>
