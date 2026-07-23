<div align="center">
<img width="1584" height="396" alt="Image" src="https://github.com/user-attachments/assets/2e5917b7-addb-46fc-8897-35ffdf235fbd" />
</div>

# Customer Churn Intelligence Platform
### From 541,909 Raw Transactions to a Retention Strategy Worth £7.7M in Predicted Value

<img alt="status" src="https://img.shields.io/badge/status-portfolio_project-1E3A5F?style=flat-square">
<img alt="data" src="https://img.shields.io/badge/data-UCI%20Online%20Retail%20(UK)-8B98AE?style=flat-square">
<img alt="stack" src="https://img.shields.io/badge/stack-Databricks%20%7C%20dbt--core%20%7C%20Python-1E3A5F?style=flat-square">
<img alt="scale" src="https://img.shields.io/badge/customers-4%2C338%20%7C%20transactions-541K%20%7C%20predicted%20CLV-%C2%A37.7M-12A879?style=flat-square">

<a href="https://github.com/Saswataghosh06/Olist-Ecommerce-Intelligence">GitHub Repo</a> · <a href="https://www.linkedin.com/in/saswata-ghosh06/">LinkedIn</a> · <a href="saswataghosh2022@gmail.com">Email</a></p>

</div>

---

## Table of Contents

- [1. Business Problem](#1-business-problem)
- [2. Objective](#2-objective)
- [3. Executive Summary](#3-executive-summary)
- [4. Data Audit & Quality](#4-data-audit--quality)
- [5. Insights Deep Dive](#5-insights-deep-dive)
- [6. Recommendations](#6-recommendations)
- [7. Interactive Dashboard](#7-interactive-dashboard)
- [8. Tech Stack & Architecture](#8-tech-stack--architecture)
- [9. Caveats & Assumptions](#9-caveats--assumptions)
- [10. Documentation Index](#10-documentation-index)

---

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
| **CLV Projection** | How much is each customer worth? | 12-month predicted lifetime value per customer |
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
| RFM segments identified | 3 named business segments (Lost/Dormant, Average, At Risk) |
| dbt tests passing | 57/57 |

**Headline finding:** 53.7% of the customer base is dormant, while a 12.9% "At Risk" segment — customers who were previously frequent, high-spending buyers — accounts for 62.8% of total customer revenue. That concentration is the core retention risk in this business: losing the wrong dozen customers matters more than losing the wrong thousand.

<p align="center">
<img width="50%" alt="Image" src="https://github.com/user-attachments/assets/d7bbe943-17d2-4c8c-b1e1-5a22208e6608" />
  <br><sub><em>3D RFM segmentation — the "At Risk" cluster (orange) sits at high frequency/monetary value with rising recency, the classic "was loyal, now fading" pattern.</em></sub>
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
| **At Risk** | 559 | 12.9% | £9,978 | ~16.0 | **62.8%** |

<p align="center">
<img width="80%" alt="Image" src="https://github.com/user-attachments/assets/ff2596bf-197d-4cd0-8808-70d6f012dc98" />
</p>

The "At Risk" segment is the priority: only 12.9% of customers, but nearly two-thirds of revenue. These are customers who *used to* buy frequently and in large volume, but recency is starting to slip.

### 5.2 CLV Projection — £7.7M in Predicted Value

A BG/NBD + Gamma-Gamma probabilistic model was attempted first — the standard approach for this kind of data. It failed to converge, because this dataset's purchase frequencies (up to 7,675 repeat purchases for one customer) and time spans sit outside what that model handles reliably. Rather than force a bad fit, the project falls back to a transparent heuristic: **AOV × (Frequency/Month) × 12**.

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
| High Risk (60–80%) | 1,834 | £681,066.49 |
| Medium Risk (40–60%) | 879 | £785,136.26 |
| Low Risk (20–40%) | 634 | £1,146,401.88 |
| Safe (<20%) | 984 | £6,150,892.18 |

**1,841 customers (42.4%) are Critical or High risk, representing £422,992.80/year in exposed revenue.**

---

## 6. Recommendations

| Priority | Recommendation | Expected Impact |
|---|---|---|
| **P1** | Launch a retention campaign targeted at the 559 "At Risk" RFM customers | Directly addresses the segment holding 62.8% of customer revenue |
| **P1** | Build a monthly engagement program (touchpoints, recommendations) to raise `engagement_score` and `active_months` | `engagement_score` is Random Forest's top-ranked feature; `active_months` is Logistic Regression's top-ranked feature — the two models agree these matter, even though they rank them differently |
| **P1** | Create a white-glove program for the 1,131 VIP-tier CLV customers | Protects £4.96M of the £7.7M predicted value pool |
| **P2** | Cross-sell campaigns to increase `unique_products` per customer | Second-strongest churn driver; also raises CLV via frequency |
| **P2** | Segment win-back campaigns by dormancy depth rather than treating all 2,331 dormant customers identically | Improves reactivation ROI |
| **P3** | Fix the `recency_days` calculation inconsistency between `mart_customer_segments` and `mart_churn_risk` (see §9) | Data-integrity cleanup, not a customer-facing action |
| **P3** | Introduce a scheduler (this project currently runs manually) to refresh CLV and churn scores on a fixed cadence | Operational readiness for production use |

---

## 7. Interactive Dashboard

*[Dashboard in progress — Power BI / interactive HTML build. Screenshots and a live file link will be added here once complete.]*

<p align="center">
  <img src="dashboard/screenshots/overview_page.png" alt="Dashboard: Overview page placeholder" width="900"/>
  <br><sub><em>[Placeholder — Overview page: KPI cards, segment distribution, CLV deciles, risk distribution]</em></sub>
</p>

<p align="center">
  <img src="dashboard/screenshots/segments_page.png" alt="Dashboard: Segments page placeholder" width="900"/>
  <br><sub><em>[Placeholder — Segments page: RFM scatter, CLV tier breakdown]</em></sub>
</p>

<p align="center">
  <img src="dashboard/screenshots/churn_page.png" alt="Dashboard: Churn risk page placeholder" width="900"/>
  <br><sub><em>[Placeholder — Churn Risk page: risk tiers, drivers, filterable at-risk registry]</em></sub>
</p>

---

## 8. Tech Stack & Architecture

The pipeline follows a Medallion architecture (Bronze → Silver → Gold) built on Databricks Unity Catalog, with dbt-core (run locally against a Databricks SQL warehouse) handling all Silver/Gold transformation and testing. **No orchestration tool (e.g., Airflow) is used** — the pipeline currently runs as a manual sequence of Databricks notebooks and dbt commands.

```
Raw CSV (541,909 rows)
   → Databricks notebook ingestion → Bronze Delta tables (Unity Catalog)
   → Databricks notebook raw EDA
   → dbt-core: Silver cleaning models → Gold business marts
   → Databricks notebooks: RFM/K-Means, CLV heuristic, churn classification
   → Enriched Gold marts → Power BI / interactive dashboard
```

| Layer | Tool |
|---|---|
| Compute & Storage | Databricks, Unity Catalog (Delta tables + Volumes) |
| Transformation | dbt-core + `dbt-databricks` adapter |
| Modeling | Python — scikit-learn (K-Means, Logistic Regression, Random Forest), `lifetimes` (attempted) |
| Visualization | matplotlib, seaborn, Power BI |
| Version control | Git + GitHub |

📄 **Full architecture, repo structure, and exact `dbt_project.yml`:** [`docs/project_architecture.md`](docs/project_architecture.md)

---

## 9. Caveats & Assumptions

Stated plainly, with no rounding in the business's favor:

- **Static dataset (Dec 2010–Dec 2011).** A production system would refresh CLV and churn scores on a schedule; seasonal effects (the November spike) may not generalize to other years.
- **CLV method is a documented heuristic, not the originally-planned probabilistic model.** BG/NBD + Gamma-Gamma failed to converge on this data's extreme frequency/time scales; the heuristic (AOV × Freq/Month × 12) is industry-standard but assumes stable purchase behavior.
- **Churn definition is a reasonable proxy, not verified ground truth.** `recency_days > 90` is used as the churn label; some customers may have seasonal (not churned) purchase patterns.
- **Two Gold marts calculate `recency_days` differently.** `mart_customer_segments` uses `CURRENT_DATE()`; `mart_churn_risk` and `mart_clv_projections` correctly anchor to the dataset's own end date (09-Dec-2011). This does not affect the RFM segment ordering (which is rank-based via `NTILE`), but the raw `recency_days` figures in the segments mart should not be read literally — full explanation in [`docs/data_quality.md`](docs/data_quality.md) §4.
- **`subscription_tier` and `monthly_fee` are synthetic fields** layered onto the real UCI transaction data (the source dataset has no subscription model). The `churn_label` generation rule is fully documented; the exact assignment rule for `subscription_tier`/`monthly_fee` was not preserved in project artifacts and is not presented as known fact — see [`docs/data_dictionary.md`](docs/data_dictionary.md).
- **Geographic bias:** ~91–92% of transactions are UK-based. International insights are directional only.
- **A minor cross-document figure discrepancy exists and is disclosed here rather than silently resolved.** An earlier draft of this README stated the VIP CLV tier at 1,149 customers (avg £4,317). The figures used throughout this version (1,131 customers, avg £4,382) come directly from the `02_CLV_churn.ipynb` notebook's printed output, which is treated as the source of truth. If you have a newer or re-run notebook output, reconcile against that rather than either number here.
- **Correlation ≠ causation.** The identified churn drivers (`active_months`, `unique_products`, `engagement_score`) are associative, from a single trained model snapshot — not causally validated via A/B testing.
- **This is a portfolio case study** built on public data to demonstrate end-to-end pipeline and modeling capability, not a live production system.

---

## 10. Documentation Index

| Document | Contents |
|---|---|
| [`docs/data_audit.md`](docs/data_audit.md) | Raw EDA — schema, nulls, duplicates, outliers, geographic/temporal bias, pre-dbt findings |
| [`docs/data_quality.md`](docs/data_quality.md) | dbt test results (57/57 passing), model-layer validation, known technical caveats |
| [`docs/data_dictionary.md`](docs/data_dictionary.md) | Column-level reference across Bronze, Silver, Gold, and enriched marts |
| [`docs/project_architecture.md`](docs/project_architecture.md) | Full pipeline diagram, tech stack, exact `dbt_project.yml`, repository structure |

<p align="center">
  <sub>Built with rigor, documented with honesty. Questions about any specific number or modeling decision — happy to walk through it.</sub>
</p>
