<div align="center">
<img width="1584" height="396" alt="Image" src="https://github.com/user-attachments/assets/2e5917b7-addb-46fc-8897-35ffdf235fbd" />
</div>

<h1 align="center">Customer Churn Analytics</h1>
<h3 align="center">From 541,909 Raw Transactions to a Retention Strategy Worth £7.7M in Predicted Value</h3>

<div align="center">

<img alt="status" src="https://img.shields.io/badge/status-portfolio_project-1E3A5F?style=flat-square">
<img alt="data" src="https://img.shields.io/badge/data-UCI%20Online%20Retail%20(UK)-8B98AE?style=flat-square">
<img alt="stack" src="https://img.shields.io/badge/stack-Databricks%20%7C%20dbt--core%20%7C%20Python-1E3A5F?style=flat-square">
<img alt="scale" src="https://img.shields.io/badge/customers-4%2C338%20%7C%20transactions-541K%20%7C%20predicted%20CLV-%C2%A37.7M-12A879?style=flat-square">

<p align="center"><b>Saswata Ghosh</b><br>
<a href="https://github.com/Saswataghosh06/Customer-Churn-Analytics">GitHub Repo</a> · <a href="https://www.linkedin.com/in/saswata-ghosh06/">LinkedIn</a> · <a href="saswataghosh2022@gmail.com">Email</a></p>

</div>

---
> **The headline:** A 12.9% "Cannot Lose Them" segment (559 customers) drives 62.8% of total revenue, while 1,841 customers (42.4%) are flagged Critical/High churn risk — £422,992.80/year in exposed revenue against a total predicted 12-month CLV of £7.7M.

**🎯 Strategy & Impact:** [Executive Summary](#3-executive-summary) → [Recommendations](#6-recommendations)
**⚙️ Architecture & Engineering:** [Data Model](#8-data-model) → [Pipeline & Orchestration](#10-pipeline--orchestration)

---

> **Note:** This is a portfolio project built on the public UCI Online Retail dataset with synthetic subscription and churn labels. It demonstrates end-to-end pipeline architecture, data quality practices, and modeling methodology.

## 1. Business Problem

A UK-based online retailer selling giftware and home accessories grew fast — monthly transaction volume climbed from the ~27,000–42,000 range in the earliest months on record to a ~85,000 peak in November 2011 — but had no systematic way to answer three questions that matter to any subscription or repeat-purchase business:

1. **Who are our best customers?**
2. **How much is each customer worth going forward?**
3. **Who is about to leave, and what would that cost us?**

Without answers, the business was acquiring customers efficiently while quietly losing the ones it already had — a retention gap that doesn't show up in a revenue chart until it's already expensive.

---

## 2. Objective

This project builds an end-to-end pipeline — from raw transaction data to a scored, segmented customer base — to answer all three questions with numbers, not guesses.

| Workstream | Business Question | Deliverable |
|---|---|---|
| **Customer Segmentation** | Who are our best customers? | RFM scoring + K-Means clustering into named business segments |
| **CLV Heuristic Estimate** | How much is each customer worth? | 12-month predicted lifetime value per customer |
| **Churn Prediction** | Who's about to leave? | Risk-scored customer list with revenue impact |

---

## 3. Executive Summary

| Metric | Value |
|---|---:|
| Customers analyzed | 4,338 |
| Valid transactions (post-cleaning) | ~392,000 |
| Total predicted 12-month CLV | **£7,702,146.93** |
| Average CLV per customer | £1,805.05 |
| Top 10% of customers' share of predicted CLV | 42.9% (£3,305,578.01) |
| At-risk customers (Critical + High risk tiers) | **1,841 (42.4%)** |
| Revenue at risk | **£422,992.80/year** |
| Best churn model | Random Forest, ROC-AUC 0.781 (LR: 0.775) |
| RFM segments identified | 3 named business segments (Lost/Dormant, Loyal/Average, Cannot Lose Them) |
| dbt tests passing | 57/57 |

**Headline finding:** 53.7% of the customer base is dormant, while a 12.9% 'Cannot Lose Them' segment — previously high-frequency, high-spending customers whose recency has increased — accounts for 62.8% of total customer revenue. That concentration is the core retention risk in this business: losing the wrong dozen customers matters more than losing the wrong thousand.

<p align="center">
<img width="50%" alt="Image" src="https://github.com/user-attachments/assets/d7bbe943-17d2-4c8c-b1e1-5a22208e6608" />
  <br><sub><em>3D RFM segmentation — the "Cannot Lose Them" cluster (orange) sits at high frequency/monetary value with rising recency, the classic "was loyal, now fading" pattern.</em></sub>
</p>

---

## 4. Data Audit & Quality

Before any model was built, the raw dataset was audited for the issues that would otherwise silently corrupt the results: null customer IDs, cancellations, invalid prices/quantities, duplicates, and geographic/temporal bias.

| Finding | Count | % of Total | Action |
|---|---:|---:|---|
| NULL `CustomerID` | 135,080 | 24.93% | Filtered — unusable for customer analytics |
| Cancelled orders (`Invoice 'C'`) | 9,288 | 1.71% | Filtered — returns distort revenue |
| `Quantity ≤ 0` | 10,624 | 1.96% | Filtered |
| `UnitPrice ≤ 0` | 2,517 | 0.46% | Filtered |
| Exact duplicate rows | 5,268 | 0.97% | Deduplicated |
| Extreme quantity/price outliers | 34 total | <0.01% | Flagged (not removed) in Gold |

<p align="center">
<img width="80%" alt="Image" src="https://github.com/user-attachments/assets/ca6bed65-c951-47f8-99b2-17f0ac8434b4" />
</p>

All 57 automated dbt tests pass on the current build (an initial run caught 4 rows with micro-value `UnitPrice`, which tightened the Silver-layer filter — the full before/after is in the linked report below).

<p align="center">
<img width="80%" alt="Image" src="https://github.com/user-attachments/assets/d8081e07-854b-446f-961c-56dc5db4533e" />
</p>

📄 **Full detail:** [`docs/data_audit.md`](docs/data_audit.md) (raw EDA — nulls, duplicates, outliers, geographic/temporal bias) · [`docs/data_quality.md`](docs/data_quality.md) (dbt test results, model validation, known technical caveats) · [`docs/data_dictionary.md`](docs/data_dictionary.md) (full column-level reference across Bronze/Silver/Gold)

---

## 5. Insights Deep Dive

### 5.1 Customer Segmentation — The 80/20 Rule, Confirmed

K-Means clustering (K=4, silhouette score 0.380 — selected over the marginally higher-scoring K=3 for business interpretability) grouped customers into three named segments:

| Segment | Customers | Share | Avg Spend | Avg Frequency | Revenue Share |
|---|---:|---:|---:|---:|---:|
| **Lost / Dormant** | 2,331 | 53.7% | £389 | ~1.5 | 10.2% |
| **Average** | 1,448 | 33.4% | £1,659 | ~4.3 | 27.0% |
| **Cannot Lose Them** | 559 | 12.9% | £9,978 | ~16.0 | **62.8%** |

<p align="center">
<img width="80%" alt="Image" src="https://github.com/user-attachments/assets/ff2596bf-197d-4cd0-8808-70d6f012dc98" />
</p>

The "Cannot Lose Them" segment is the priority: only 12.9% of customers, but nearly two-thirds of revenue. These are previously loyal, high-value customers whose purchase recency has increased — the classic fading-VIP pattern.


### 5.2 CLV Projection — £7.7M in Predicted Value

A BG/NBD + Gamma-Gamma probabilistic model was attempted first — the standard approach for non-contractual CLV. It failed to converge due to extreme frequency values in this dataset... Rather than force an invalid model, the project uses a transparent industry heuristic: **AOV × (Frequency/Month) × 12**.

<p align="center">
<img width="80%" alt="Image" src="https://github.com/user-attachments/assets/a905cee3-67bb-4d3b-a1c6-ef4715898600" />
</p>

| CLV Tier | Customers | Combined CLV | Avg CLV |
|---|---:|---:|---:|
| VIP | 1,131 | £4,956,552.28 | ~£4,382 |
| High Value | 1,156 | £1,722,496.03 | ~£1,490 |
| Medium Value | 1,010 | £737,566.26 | ~£730 |
| Low Value | 702 | £250,574.04 | ~£357 |
| Minimal Value | 268 | £34,958.32 | ~£130 |

The top 10% of customers by CLV hold **42.9%** of the total £7.7M predicted value — a concentration that makes the VIP tier the single highest-leverage retention target in the business.

### 5.3 Churn Prediction — Catching a Real Modeling Mistake

The first churn model scored 100% accuracy and AUC = 1.000. That is not a result to celebrate — it's a signal something is wrong. The cause: `recency_days` was included as a feature, but `recency_days > 90` is also the literal definition of the `churn_label` target. The model was being asked to predict a label from its own definition.

After removing `recency_days` and `customer_lifespan_days` and rebuilding:

| Model | ROC-AUC | 5-Fold CV ROC-AUC | Notes |
|---|---:|---:|---|
| Logistic Regression (primary) | 0.775 | 0.775 (± 0.036) | Interpretable, production-ready |
| Random Forest (benchmark) | 0.781 | 0.783 (± 0.036) | Best model, used for scoring |

<p align="center">
<img width="80%" alt="Image" src="https://github.com/user-attachments/assets/6a5abe54-3d8f-4e85-95ee-ccba97c2fd28" />
</p>

<p align="center">
<img width="80%" alt="Image" src="https://github.com/user-attachments/assets/89129b06-aeb9-4c6a-b1d8-22d59a65a45d" /></p>

**Top churn drivers, by model:**

| Rank | Logistic Regression (coefficient) | Random Forest (feature importance) |
|---|---|---|
| 1 | `active_months` (protective) | `engagement_score` |
| 2 | `unique_products` (protective) | `total_transactions` |
| 3 | `spend_per_product` (risk factor) | `purchase_regularity` |

The two models don't agree on a single #1 driver — `active_months` ranks 1st in Logistic Regression but only 5th in Random Forest, and `unique_products` ranks 2nd in LR but 6th in RF. The one factor both models rank near the top is **`engagement_score`** (1st in RF, 4th in LR). The honest read: low engagement and fewer active months/products are all directionally associated with churn, but the models don't fully agree on which single feature matters most.

**Resulting risk tiers:**

| Risk Tier | Customers | Combined Historical Spend |
|---|---:|---:|
| Critical Risk (80%+) | 7 | £123,712.08 |
| High Risk (60–80%) | 1,834 | £681,066.$ |
| Medium Risk (40–60%) | 879 | £785,136.26 |
| Low Risk (20–40%) | 634 | £1,146,401.88 |
| Safe (<20%) | 984 | £6,150,892.18 |

**1,841 customers (42.4%) are Critical or High risk, representing £422,992.80/year in exposed revenue.**

---

## 6. Recommendations

| Priority | Recommendation | Expected Impact |
|---|---|---|
| **P1** | Launch a retention campaign targeted at the 559 "Cannot Lose Them" RFM customers | Directly addresses the segment holding 62.8% of customer revenue |
| **P1** | Build a monthly engagement program (touchpoints, recommendations) to raise `engagement_score` and `active_months` | `engagement_score` is Random Forest's top-ranked feature; `active_months` is Logistic Regression's top-ranked feature — the two models agree these matter, even though they rank them differently |
| **P1** | Create a white-glove program for the 1,131 VIP-tier CLV customers | Protects £4.96M of the £7.7M predicted value pool |
| **P2** | Cross-sell campaigns to increase `unique_products` per customer | Second-strongest churn driver; also raises CLV via frequency |
| **P2** | Segment win-back campaigns by dormancy depth rather than treating all 2,331 dormant customers identically | Improves reactivation ROI |
| **P3** | Introduce a scheduler (this project currently runs manually) to refresh CLV and churn scores on a fixed cadence | Operational readiness for production use |

---

## 7. Architecture

The pipeline follows a Medallion architecture (Bronze → Silver → Gold) built on Databricks Unity Catalog, with dbt-core (run locally against a Databricks SQL warehouse) handling all Silver/Gold transformation and testing. **No orchestration tool (e.g., Airflow) is used** — the pipeline currently runs as a manual sequence of Databricks notebooks and dbt commands.

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

---

## 8. Data Model

### Star Schema

<div align="center">
<img width="3197" height="2486" alt="Image" src="https://github.com/user-attachments/assets/ba95e7ef-ed53-4baa-8c13-37c215401d81" />
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

<details>
<summary><b>🔧 Sample SQL Models (Click to Expand)</b></summary>

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
{{ config(materialized='table', schema='gold', tags7Ctags=['gold', 'churn', 'ml-features']) }}

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
</details>

---

## 9. Data Quality

57 automated dbt tests across all layers. Full audit → [`docs/data_audit.md`](./docs/data_audit.md)

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

## 10. Pipeline & Orchestration

The pipeline runs as a **manual sequence** — no orchestration tool is used:

```text
1. Databricks notebook — data ingestion (CSV → Bronze Delta tables)
2. Databricks notebook — raw EDA
3. dbt-core (local) — Silver cleaning + Gold mart building
4. Databricks notebooks — RFM/K-Means, CLV, churn classification
5. Power BI / interactive dashboard
```

<details>
<summary><b>🔧 dbt Project Configuration (Click to Expand)</b></summary>

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
</details>

### Technology Stack

| Layer | Tool |
|---|---|
| Compute & Storage | Databricks, Unity Catalog (Delta tables + Volumes) |
| Transformation | dbt-core + `dbt-databricks` adapter |
| Modeling | Python — scikit-learn (K-Means, Logistic Regression, Random Forest), `lifetimes` (attempted) |
| Visualization | matplotlib, seaborn, Power BI |
| Version control | Git + GitHub |

---

## 11. Technical Decisions & Trade-offs

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

## 12. Caveats & Assumptions

Stated plainly, with no rounding in the business's favor:

- **Static dataset (Dec 2010–Dec 2011).** A production system would refresh CLV and churn scores on a schedule; seasonal effects (the November spike) may not generalize to other years.
- **CLV method is a documented heuristic, not the originally-planned probabilistic model.** BG/NBD + Gamma-Gamma failed to converge on this data's extreme frequency/time scales; the heuristic (AOV × Freq/Month × 12) is industry-standard but assumes stable purchase behavior.
- **Churn definition is a reasonable proxy, not verified ground truth.** `recency_days > 90` is used as the churn label; some customers may have seasonal (not churned) purchase patterns.
- **`recency_days` is calculated consistently** across all Gold marts using the dataset's observation end date (09-Dec-2011). `mart_customer_segments` uses `CURRENT_DATE()`; `mart_churn_risk` and `mart_clv_projections` correctly anchor to the dataset's own end date (09-Dec-2011). This does not affect the RFM segment ordering (which is rank-based via `NTILE`), but the raw `recency_days` figures in the segments mart should not be read literally — full explanation in [`docs/data_quality.md`](./docs/data_quality.md) §4.
- **`subscription_tier` and `monthly_fee` are synthetic fields** layered onto the real UCI transaction data. `churn_label` is generated via `recency_days > 90`.
- **Geographic bias:** ~91–92% of transactions are UK-based. International insights are directional only.
- **Correlation ≠ causation.** The identified churn drivers (`active_months`, `unique_products`, `engagement_score`) are associative, from a single trained model snapshot — not causally validated via A/B testing.
- **This is a portfolio case study** built on public data to demonstrate end-to-end pipeline and modeling capability, not a live production system.

---

## 13. Documentation Index

| Document | Contents |
|---|---|
| [`docs/data_audit.md`](docs/data_audit.md) | Raw EDA — schema, nulls, duplicates, outliers, geographic/temporal bias, pre-dbt findings |
| [`docs/data_quality.md`](docs/data_quality.md) | dbt test results (57/57 passing), model-layer validation, data governance standards |
| [`docs/data_dictionary.md`](docs/data_dictionary.md) | Column-level reference across Bronze, Silver, Gold, and enriched marts |
| [`docs/project_architecture.md`](docs/project_architecture.md) | Full pipeline diagram, tech stack, exact `dbt_project.yml`, repository structure |

---

<p align="center">
  <sub>Built with rigor, documented with honesty. Questions about any specific number or modeling decision — happy to walk through it.</sub>
</p>
