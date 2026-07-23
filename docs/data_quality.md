# Data Quality Report

## Overview

This document tracks data quality across the entire pipeline: from raw ingestion, through dbt transformations, through model training, to final scored outputs. It reflects the actual test results and validation checks run on this project — no rounded or assumed figures.

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
| NULL `CustomerID` | 135,080 | 24.93% | HIGH | Filter out in Silver |
| NULL `Description` | 1,454 | 0.27% | LOW | Acceptable — not used in customer-level analytics |
| Cancelled Orders (`InvoiceNo` starts with `C`) | 9,288 | 1.71% | INFO | Filter out in Silver |
| `Quantity` ≤ 0 | 10,624 | 1.96% | MEDIUM | Filter out in Silver |
| `UnitPrice` ≤ 0 | 2,517 | 0.46% | MEDIUM | Filter out in Silver |
| `UnitPrice` < 0.01 (micro-values) | 4 | <0.01% | MEDIUM | Filter tightened to ≥ 0.01 |
| Exact duplicate rows | 5,268 | 0.97% | LOW | `DISTINCT` in Silver |
| Extreme `Quantity` (>10,000) | 3 | <0.01% | MEDIUM | Flagged (not removed) in Gold |
| Extreme `UnitPrice` (>£5,000) | 31 | <0.01% | MEDIUM | Flagged (not removed) in Gold |

### Geographic Bias
- United Kingdom: 495,478 transactions (91.4% of raw rows)
- Remaining 9 top countries combined: <9%
- **Impact:** Geographic segmentation is only reliable for the UK market; international insights are directional only.

### Temporal Bias
- Dataset ends 09-Dec-2011 — December is a partial month and appears artificially low in any month-over-month chart.
- November 2011 is the peak month (~85,000 transactions), consistent with UK holiday shopping season.
- **Impact:** Any month-level trend must account for the truncated final month.

### Customer-Level Profile (post-cleaning, 4,338 valid customers)
- Mean total spend: £2,054.27 | Median: £674.49 | Std dev: £8,989.23
- Mean vs. median gap (3×) confirms strong right-skew — a small number of very high spenders.
- Top single customer by spend: CustomerID 14646, £280,206.02 across 73 transactions.

### Correlation Finding
- `total_spend` and `total_items` correlate at 0.92 — expected (more items purchased naturally means more spend), but flagged to avoid multicollinearity if used as raw features together in modeling. Addressed by engineering ratio features (`spend_per_transaction`, `items_per_transaction`, etc.) in `mart_churn_risk`.

---

## Phase 2: dbt Data Quality (Automated Tests)

### Test Results Summary

| Run | Tests | Passed | Failed | Notes |
|---|---|---|---|---|
| Initial | 57 | 55 | 2 | 4 rows with `UnitPrice` < 0.01 caught by range test |
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
  - **K=4 was selected** for business interpretability — it separates a distinct "At Risk" high-value cluster from the broader "Average" group, which K=3 does not cleanly do
- **Result:** 4 numeric clusters mapped to 3 business names (two clusters both mapped to "Lost / Dormant" since they represent the same business behavior at slightly different recency bands)

| Business Segment | Customers | % of Base | Revenue Share |
|---|---:|---:|---:|
| Lost / Dormant | 2,331 | 53.7% | £906,648 (10.2%) |
| Average | 1,448 | 33.4% | £2,402,775 (27.0%) |
| At Risk | 559 | 12.9% | £5,577,786 (62.8%) |

### 3.2 CLV Projection (`02_CLV_churn.ipynb`)
- **Input:** 4,338 customers from `mart_churn_risk`/`mart_clv_projections`; 4,267 passed `lifetimes`-format validation (71 one-time buyers with `frequency = 0` excluded by design, not by failure)
- **Validation checks run:** `frequency = 0` count, `recency < 0` count, `T < recency` count, `monetary ≤ 0` count — all returned **0** violations on the 4,267 modeled rows
- **BG/NBD + Gamma-Gamma attempt:** Failed to converge — attributed to extreme scale in `frequency` (up to 7,675 repeat purchases) and `T` (up to 373 days), which violate the model's typical assumptions
- **Fallback method used:** Heuristic CLV = `AOV × (Frequency/Month) × 12` — industry-standard, documented explicitly as a heuristic rather than a probabilistic estimate
- **Post-fit check:** 0 `inf`/`NaN` values across 4,267 CLV outputs
- **Result:** Total 12-month predicted CLV = **£7,702,146.93**; average £1,805.05/customer; top 10% of customers hold **42.9%** of total predicted value (£3,305,578.01)

### 3.3 Churn Prediction (`03_Churn_Prediction.ipynb`)

**The target leakage incident:**
- Initial feature set included `recency_days`, which is also the direct input to the `churn_label` definition (`recency_days > 90`)
- Initial result: 100% accuracy, ROC-AUC = 1.000 — flagged immediately as unrealistic and investigated rather than reported
- **Fix:** Removed `recency_days` and `customer_lifespan_days` from the feature set (14 features retained), rebuilt both models

| Model | Accuracy | Precision | Recall | F1 | ROC-AUC | 5-Fold CV ROC-AUC |
|---|---:|---:|---:|---:|---:|---:|
| Logistic Regression (primary) | 0.657 | 0.492 | 0.800 | 0.609 | 0.775 | 0.775 (± 0.036) |
| Random Forest (benchmark) | 0.695 | 0.531 | 0.741 | 0.619 | 0.781 | 0.783 (± 0.036) |

- **Train/test split:** 3,470 train / 868 test (80/20), churn rate held constant at 33.4% across both splits
- **Overall churn rate:** 1,449 of 4,338 customers churned (33.4%)
- **Risk tiers from Random Forest scoring:**

| Risk Tier | Customers | Combined Historical Spend | Avg Risk Score |
|---|---:|---:|---:|
| Critical Risk (80%+) | 7 | £123,712.08 | 0.87 |
| High Risk (60–80%) | 1,834 | £681,066.49 | 0.70 |
| Medium Risk (40–60%) | 879 | £785,136.26 | 0.51 |
| Low Risk (20–40%) | 634 | £1,146,401.88 | 0.30 |
| Safe (<20%) | 984 | £6,150,892.18 | 0.07 |

- **Combined at-risk (Critical + High):** 1,841 customers (42.4%), £422,992.80/year revenue at risk

---

## Phase 4: Known Technical Caveats (Documented, Not Hidden)

### 4.1 `recency_days` calculation inconsistency between marts
- `gold.mart_customer_segments` calculates `recency_days` as `DATEDIFF(day, MAX(invoice_timestamp), CURRENT_DATE())` — i.e., against the date the model is *run*, not the dataset's observation window.
- `gold.mart_churn_risk` and `gold.mart_clv_projections` correctly calculate recency/`T` against the dataset's own max invoice date (09-Dec-2011), with an explicit code comment noting that using `CURRENT_DATE()` would distort the figure by over a decade.
- **Effect on results:** None on the segmentation itself. `r_score` is computed with `NTILE(5)` — a relative rank across customers — so the *ordering* of customers from most-to-least recent is unaffected by which fixed reference date is used. The absolute `recency_days` values in `mart_customer_segments` (observed range: ~5,337–5,710 days in the current run) should not be read as a literal "days since last purchase" figure; the `mart_churn_risk` version of `recency_days` is the reliable one for that purpose.
- **Status:** Documented here as a known inconsistency between two Gold models built in the same project. Recommended fix: standardize `mart_customer_segments` to use the same `MAX(invoice_timestamp)` reference date used elsewhere.

### 4.2 Synthetic subscription fields
- `subscription_tier` and `monthly_fee` in `bronze.customers_simulated` are synthetic additions layered on top of the real UCI transaction data, since the source dataset has no subscription model. `churn_label`'s generation rule is explicitly documented (`recency_days > 90`); the precise assignment logic for `subscription_tier`/`monthly_fee` was not preserved in the artifacts available for this documentation pass and is not stated here as fact — see `data_dictionary.md` §1.2.

### 4.3 RFM score direction is inverted in `mart_customer_segments` (confirmed via cluster output)

**The bug, in the SQL:**
```sql
NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,      -- Lower recency = higher score
NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,        -- Higher frequency = higher score
NTILE(5) OVER (ORDER BY monetary DESC) AS m_score,         -- Higher monetary = higher score
```

`NTILE(n)` assigns bucket 1 to the first rows in the stated sort order and bucket `n` to the last. Under `ORDER BY recency_days ASC`, bucket 1 goes to the *smallest* recency_days (most recent buyers) — not bucket 5, as the comment and `schema.yml` ("5 = most recent") both intend. The same inversion applies to `f_score` and `m_score` under their `DESC` clauses (bucket 1 goes to the *highest* frequency/spend, not bucket 5).

**Confirmed with real data, not just static code review.** In `01_rfm_kmeans_clustering.ipynb`, the `customer_segment` column produced by this mart is used as a diagnostic "mode label" per K-Means cluster. Cluster 1 is mode-labeled **`"Champions"`** by that column, yet its own stats are:

| Metric | Cluster 1 value | What "Champions" should look like |
|---|---|---|
| Avg recency_days | 5,595 (highest of any cluster — most dormant) | Lowest |
| Avg frequency | 1.38 (lowest of any cluster) | Highest |
| Avg monetary | £388.43 (lowest of any cluster) | Highest |

This is the empirical fingerprint of the inversion: the objectively worst-behaving cluster in the dataset is labeled "Champions" by the rule-based logic.

**Scope of impact:**
- **Does not affect** the business segments reported in the README/executive summary (Lost/Dormant, Average, At Risk) — those come from K-Means clustering directly on raw `recency_days`/`frequency`/`monetary`, not from this scored/labeled column.
- **Does affect** `r_score`, `f_score`, `m_score`, `rfm_score`, `rfm_segment_code`, `customer_segment`, and `business_priority` in `gold.mart_customer_segments` as currently built — all inherit the inversion, meaning the mart currently mislabels its best and worst customers in reverse.
- **Not caught by dbt tests.** The `accepted_values` test on `customer_segment` only validates that the label is one of the 8 allowed strings — it has no way to check whether the *assignment* is directionally correct, so all 57 tests pass despite the bug.

**Fix:** flip the sort direction in each `NTILE` call — `recency_days DESC`, `frequency ASC`, `monetary ASC` — so that bucket 5 consistently represents "best" across all three dimensions, matching the documented intent.

---

## Data Quality Maturity Scorecard

| Dimension | EDA | dbt Tests | Model Validation | Maturity |
|---|---|---|---|---|
| Null detection | Manual | Automated | N/A | Production-ready |
| Range validation | Visual | Automated | N/A | Production-ready |
| Uniqueness | Group-by | Automated | N/A | Production-ready |
| Referential integrity | N/A | Cross-model `ref()` | N/A | Production-ready |
| Accepted values | N/A | Automated | N/A | Production-ready |
| Target leakage | N/A | N/A | Caught & fixed | Production-ready |
| Model convergence | N/A | N/A | Monitored & documented (BG/NBD failure) | Production-ready |
| Cross-mart consistency | N/A | N/A | Identified (§4.1) | Known gap, documented |
| RFM score directionality | N/A | Not caught — `accepted_values` only checks label spelling | Caught via cluster output review (§4.3) | Known bug, documented |
| Documentation | Markdown | dbt schema.yml | Notebook comments + this report | Production-ready |

---

## Recommendations for Production

1. Standardize the recency reference date across all Gold marts (fix §4.1).
2. **Fix the `NTILE` sort direction on `r_score`/`f_score`/`m_score` in `mart_customer_segments.sql`** so scores actually match their documented "5 = best" convention (fix §4.3) — this is the highest-priority fix among all findings in this report, since it currently produces a mislabeled business-facing field.
3. Preserve and document the exact generation rule for any future synthetic/simulated fields at creation time, not after the fact.
4. Add dbt source freshness tests on `bronze.online_retail` to detect stale ingestion.
5. Introduce an orchestration layer (this project currently runs dbt-core manually against Databricks — no scheduler is in place yet) to automate the Bronze → Silver → Gold → notebook-scoring sequence.
6. Add anomaly detection for sudden spikes in cancellations or returns.
7. Monitor churn model drift and retrain on a fixed cadence (e.g., monthly) once in a live setting.