# Data Quality Report

## Overview

This document tracks data quality across the entire pipeline: from raw ingestion through dbt transformations, model training, and final scored outputs. All figures reflect the actual test results and validation checks run on this project.

**Pipeline covered:** Bronze (raw ingestion) → Silver (dbt cleaning) → Gold (dbt marts) → Notebook models (K-Means, CLV heuristic, churn classifiers) → Enriched Gold outputs.

---

## Phase 1: Raw Data Quality (EDA Findings)

### Dataset: UCI Online Retail
- **Total Rows:** 541,909
- **Columns:** 8
- **Date Range:** 01-Dec-2010 to 09-Dec-2011 (373 days)
- **Encoding:** ISO-8859-1
- **Date Format:** `dd-MM-yyyy HH:mm`

### Quality Issues Identified

| Issue | Count | Percentage | Severity | Action |
|---|---|---|---|---|
| NULL `CustomerID` | 135,080 | 24.93% | HIGH | Filtered out in Silver |
| NULL `Description` | 1,454 | 0.27% | LOW | Acceptable — not used in customer-level analytics |
| Cancelled Orders (`InvoiceNo` starts with `C`) | 9,288 | 1.71% | INFO | Filtered out in Silver |
| `Quantity` ≤ 0 | 10,624 | 1.96% | MEDIUM | Filtered out in Silver |
| `UnitPrice` ≤ 0 | 2,517 | 0.46% | MEDIUM | Filtered out in Silver |
| `UnitPrice` &lt; 0.01 (micro-values) | 4 | &lt;0.01% | MEDIUM | Filter tightened to ≥ 0.01 |
| Exact duplicate rows | 5,268 | 0.97% | LOW | Deduplicated via `DISTINCT` in Silver |
| Extreme `Quantity` (&gt;10,000) | 3 | &lt;0.01% | MEDIUM | Flagged (not removed) in Gold |
| Extreme `UnitPrice` (&gt;£5,000) | 31 | &lt;0.01% | MEDIUM | Flagged (not removed) in Gold |

### Geographic Bias
- United Kingdom: 495,478 transactions (91.4% of raw rows)
- Remaining 9 top countries combined: &lt;9%
- **Impact:** Geographic segmentation is reliable for the UK market; international insights are directional only.

### Temporal Bias
- Dataset ends 09-Dec-2011 — December is a partial month and appears artificially low in month-over-month charts.
- November 2011 is the peak month (~85,000 transactions), consistent with UK holiday shopping season.
- **Impact:** Month-level trends account for the truncated final month.

### Customer-Level Profile (post-cleaning, 4,338 valid customers)
- Mean total spend: £2,054.27 | Median: £674.49 | Std dev: £8,989.23
- Mean vs. median gap (3×) confirms strong right-skew — a small number of very high spenders.
- Top single customer by spend: CustomerID 14646, £280,206.02 across 73 transactions.

### Correlation Finding
- `total_spend` and `total_items` correlate at 0.92 — expected, but flagged to avoid multicollinearity in modeling. Addressed by engineering ratio features (`spend_per_transaction`, `items_per_transaction`, `spend_per_product`, `purchase_regularity`) in `mart_churn_risk`.

---

## Phase 2: dbt Data Quality (Automated Tests)

### Test Results Summary

| Run | Tests | Passed | Failed | Notes |
|---|---|---|---|---|
| Initial | 57 | 55 | 2 | 4 rows with `UnitPrice` &lt; 0.01 caught by range test |
| After fix | 57 | 57 | 0 | Filter tightened to `UnitPrice ≥ 0.01` in `stg_transactions` |

### Tests by Model

**`silver.stg_transactions`**
- `not_null`: `InvoiceNo`, `StockCode`, `Quantity`, `invoice_timestamp`, `UnitPrice`, `CustomerID`, `line_total`
- `accepted_range`: `Quantity` ≥ 1, `UnitPrice` ≥ 0.01, `line_total` ≥ 0.01

**`silver.stg_customers`**
- `not_null` + `unique`: `CustomerID`
- `accepted_values`: `subscription_tier` in [Basic, Standard, Premium, Enterprise]
- `accepted_range`: `monthly_fee` ≥ 0
- `accepted_values`: `churn_label` in [0, 1]

**`gold.mart_customer_segments`**
- `not_null` + `unique`: `CustomerID`
- `accepted_range`: `r_score`, `f_score`, `m_score` in [1, 5]
- `accepted_values`: `customer_segment` in [Champions, Loyal Customers, New Customers, Potential Loyalists, At Risk, Cannot Lose Them, Lost, Others]

**`gold.mart_clv_projections`**
- `not_null` + `unique`: `CustomerID`
- `accepted_range`: `frequency` ≥ 1, `recency` ≥ 0, `T` ≥ 0, `monetary_value` ≥ 0

**`gold.mart_churn_risk`**
- `not_null` + `unique`: `CustomerID`
- `accepted_values`: `churn_label` in [0, 1]
- `accepted_range`: `total_transactions` ≥ 1, `total_spend` ≥ 0, `recency_days` ≥ 0

---

## Phase 3: Modeling-Layer Validation

### 3.1 RFM K-Means Clustering (`01_rfm_kmeans_clustering.ipynb`)
- **Input:** 4,338 customers from `mart_customer_segments`
- **Features:** `recency_days`, `frequency`, `monetary` — log-transformed, then `StandardScaler`-scaled
- **K selection tested:** K=2 through K=10, comparing inertia (elbow) and silhouette score
  - Silhouette peaked at **K=3 (0.415)**, with **K=4 close behind (0.380)**
  - **K=4 was selected** for business interpretability — it separates a distinct high-value cluster from the broader mid-tier group, which K=3 does not cleanly do
- **Result:** 4 numeric clusters mapped to 3 business segments

| Segment | Customers | % of Base | Avg Spend | Avg Frequency | Revenue Share |
|---|---:|---:|---:|---:|---:|
| **Lost / Dormant** | 2,331 | 53.7% | £389 | ~1.5 | 10.2% |
| **Loyal / Average** | 1,448 | 33.4% | £1,659 | ~4.3 | 27.0% |
| **Cannot Lose Them** | 559 | 12.9% | £9,978 | ~16.0 | **62.8%** |

&gt; **Note:** The "Cannot Lose Them" segment represents previously high-frequency, high-monetary customers whose recency has increased. These are the highest-priority retention target — a small population driving the majority of revenue.

### 3.2 CLV Heuristic Estimate (`02_CLV_churn.ipynb`)
- **Input:** 4,338 customers from `mart_churn_risk`/`mart_clv_projections`; 4,267 passed `lifetimes`-format validation (71 one-time buyers with `frequency = 0` excluded by design)
- **Validation checks run:** `frequency = 0` count, `recency &lt; 0` count, `T &lt; recency` count, `monetary ≤ 0` count — all returned **0** violations on the 4,267 modeled rows
- **BG/NBD + Gamma-Gamma attempt:** Failed to converge due to extreme scale in `frequency` (up to 7,675 repeat purchases) and `T` (up to 373 days), which violate the model's typical assumptions
- **Method used:** Heuristic CLV = `AOV × (Frequency/Month) × 12` — industry-standard, documented explicitly as a heuristic rather than a probabilistic estimate
- **Post-fit check:** 0 `inf`/`NaN` values across 4,267 CLV outputs
- **Result:** Total 12-month predicted CLV = **£7,702,146.93**; average £1,805.05/customer; top 10% of customers hold **42.9%** of total predicted value (£3,305,578.01)

| CLV Tier | Customers | Combined CLV | Avg CLV |
|---|---:|---:|---:|
| VIP | 1,131 | £4,956,552.28 | ~£4,382 |
| High Value | 1,156 | £1,722,496.03 | ~£1,490 |
| Medium Value | 1,010 | £737,566.26 | ~£730 |
| Low Value | 702 | £250,574.04 | ~£357 |
| Minimal Value | 268 | £34,958.32 | ~£130 |

### 3.3 Churn Prediction (`03_Churn_Prediction.ipynb`)

**Feature Independence Validation**
Before training, all features were screened against the target definition. `recency_days` and `customer_lifespan_days` were identified as structurally dependent on `churn_label` (defined as `recency_days &gt; 90`) and removed from the feature set. This validation step ensured the model learns behavioral patterns rather than circular definitions.

| Model | Accuracy | Precision | Recall | F1 | ROC-AUC | 5-Fold CV ROC-AUC |
|---|---:|---:|---:|---:|---:|---:|
| Logistic Regression (primary) | 0.657 | 0.492 | 0.800 | 0.609 | 0.775 | 0.775 (± 0.036) |
| Random Forest (benchmark) | 0.695 | 0.531 | 0.741 | 0.619 | 0.781 | 0.783 (± 0.036) |

- **Train/test split:** 3,470 train / 868 test (80/20), stratified to hold churn rate constant at 33.4% across both splits
- **Overall churn rate:** 1,449 of 4,338 customers churned (33.4%)
- **Risk tiers from Random Forest scoring:**

| Risk Tier | Customers | Combined Historical Spend | Avg Risk Score |
|---|---:|---:|---:|
| Critical Risk (80%+) | 7 | £123,712.08 | 0.87 |
| High Risk (60–80%) | 1,834 | £681,066.49 | 0.70 |
| Medium Risk (40–60%) | 879 | £785,136.26 | 0.51 |
| Low Risk (20–40%) | 634 | £1,146,401.88 | 0.30 |
| Safe (&lt;20%) | 984 | £6,150,892.18 | 0.07 |

- **Combined at-risk (Critical + High):** 1,841 customers (42.4%), £422,992.80/year revenue at risk

**Top churn drivers (Random Forest feature importance):**
1. `engagement_score`
2. `total_transactions`
3. `purchase_regularity`
4. `active_months`
5. `spend_per_product`

---

## Phase 4: Data Governance Standards

### Cross-Mart Consistency
- `recency_days` is calculated consistently across all Gold marts using the dataset's observation end date (09-Dec-2011), ensuring comparable time windows for segmentation, CLV, and churn features.

### RFM Score Directionality
- `r_score`, `f_score`, and `m_score` in `mart_customer_segments` use `NTILE(5)` with sort directions that align score 5 with "best" behavior: lowest recency, highest frequency, highest monetary value.

### Synthetic Data Transparency
- `subscription_tier` and `monthly_fee` in `bronze.customers_simulated` are synthetic fields layered onto the real UCI transaction data (the source dataset has no subscription model). `churn_label` is generated via the documented rule `recency_days &gt; 90`. All downstream models and marts treat these as simulated attributes.

---

## Data Quality Maturity Assessment

| Dimension | EDA | dbt Tests | Model Validation | Maturity |
|---|---|---|---|---|
| Null detection | Manual | Automated | N/A | Demonstrated |
| Range validation | Visual | Automated | N/A | Demonstrated |
| Uniqueness | Group-by | Automated | N/A | Demonstrated |
| Referential integrity | N/A | Cross-model `ref()` | N/A | Demonstrated |
| Accepted values | N/A | Automated | N/A | Demonstrated |
| Target leakage prevention | N/A | N/A | Validated & removed | Demonstrated |
| Model convergence | N/A | N/A | Monitored & documented | Demonstrated |
| Cross-mart consistency | N/A | N/A | Standardized | Demonstrated |
| RFM score directionality | N/A | Custom logic verified | Validated | Demonstrated |
| Documentation | Markdown | dbt schema.yml | Notebook comments + this report | Portfolio-grade |

---

## Next Steps

1. **Add dbt source freshness tests** on `bronze.online_retail` to detect stale ingestion.
2. **Add custom business-logic tests** for `customer_segment` (e.g., validate that "Champions" have above-median frequency and monetary, below-median recency).
3. **Introduce orchestration** (Airflow or GitHub Actions) to automate the Bronze → Silver → Gold → notebook-scoring sequence.
4. **Add holdout validation** for the CLV heuristic by comparing predicted vs. actual spend on a time-split test set.
5. **Monitor churn model drift** and retrain on a fixed cadence once in a live setting.