<div align="center">
  <img width="180px" src="https://img.shields.io/badge/Customer%20Churn%20Intelligence-1E3A5F?style=for-the-badge&logo=databricks&logoColor=white" />
</div>

<h1 align="center">Customer Churn Intelligence Platform</h1>
<h3 align="center">End-to-End Pipeline: From 541K Raw Transactions to Actionable Retention Strategy</h3>

<p align="center">
  <img alt="status" src="https://img.shields.io/badge/status-portfolio_case_study-1E3A5F?style=flat-square">
  <img alt="data" src="https://img.shields.io/badge/data-UCI%20Online%20Retail%20(UK)-8B98AE?style=flat-square">
  <img alt="stack" src="https://img.shields.io/badge/stack-Databricks%20%7C%20dbt%20%7C%20PySpark%20%7C%20Python-1E3A5F?style=flat-square">
  <img alt="scale" src="https://img.shields.io/badge/customers-4%2C338%20%7C%20transactions-541K%20%7C%20predicted%20CLV-%C2%A37.7M-12A879?style=flat-square">
</p>

<p align="center">
  <a href="https://www.linkedin.com/in/your-profile/">LinkedIn</a> · 
  <a href="https://github.com/your-username/customer-churn-intelligence">GitHub Repo</a> · 
  <a href="mailto:your.email@example.com">Email</a>
</p>

---

## The Hook

> **This project started with a model that scored 100% accuracy. That was the first red flag.**

A UK-based online retailer with ~4,300 customers and 541K transactions was burning cash on acquisition while losing customers silently. The CEO needed three answers before the next board meeting: *Who are our best customers? How much is each worth? Who's about to leave?*

I built an end-to-end data pipeline and analytics system that answers all three. Along the way, I caught a critical modeling mistake that would have misled the entire retention strategy — and fixed it before a single stakeholder saw the numbers.

---

## Table of Contents

- [1. Business Problem](#1-business-problem)
- [2. Objective](#2-objective)
- [3. Executive Summary](#3-executive-summary)
- [4. Data Audit & Quality](#4-data-audit--quality)
- [5. Insights Deep Dive](#5-insights-deep-dive)
  - [5.1 Data Profile: What 541K Transactions Reveal](#51-data-profile-what-541k-transactions-reveal)
  - [5.2 Customer Segmentation: The 80/20 Rule Is Real](#52-customer-segmentation-the-8020-rule-is-real)
  - [5.3 CLV Projection: £7.7M in Predicted Value](#53-clv-projection-77m-in-predicted-value)
  - [5.4 Churn Prediction: 1,841 Customers at Risk](#54-churn-prediction-1841-customers-at-risk)
- [6. Recommendations](#6-recommendations)
- [7. Interactive Dashboard](#7-interactive-dashboard)
- [8. Tech Stack & Architecture](#8-tech-stack--architecture)
- [9. Data Quality & Model Rigor](#9-data-quality--model-rigor)
- [10. Caveats & Assumptions](#10-caveats--assumptions)

---

## 1. Business Problem

**TechSphere** (pseudonym) is a UK-based direct-to-consumer online retailer selling giftware and home accessories. Established in 2010, the company experienced rapid growth — transaction volume tripled in under a year — but faced a critical blind spot: **customer retention**.

The business was acquiring customers efficiently but had no systematic way to:
- Identify which customers were most valuable
- Predict how much revenue each customer would generate
- Spot customers about to churn before they disappeared

**The stakes:** With 53.7% of the customer base already dormant and 12.9% of customers generating 62.8% of revenue, losing even a handful of high-value customers would have a disproportionate impact on the bottom line.

---

## 2. Objective

**The question this project answers:**

> *If we know who our customers are and what they bought, why can't we predict who's about to leave — and what would it cost us if we don't?*

This required three integrated workstreams:

| Workstream | Business Question | Deliverable |
|:---|:---|:---|
| **Customer Segmentation** | Who are our best customers? | RFM-based segments with K-Means clustering |
| **CLV Projection** | How much is each customer worth? | 12-month predicted lifetime value per customer |
| **Churn Prediction** | Who's about to leave? | Risk scores for 4,338 customers with revenue impact |

---

## 3. Executive Summary

| Metric | Value | Business Impact |
|:---|---:|:---|
| **Total customers analyzed** | 4,338 | Full customer base post-data cleaning |
| **Total transactions** | ~392,000 | After removing nulls, cancellations, duplicates |
| **Total predicted 12-month CLV** | **£7.7 million** | Revenue forecast for retention planning |
| **Average CLV per customer** | £1,805 | Benchmark for acquisition cost optimization |
| **Top 10% customers** | 42.9% of total CLV | Concentration risk — losing 10% = losing nearly half |
| **At-risk customers** | **1,841 (42.5%)** | Immediate retention campaign target |
| **Revenue at risk** | **£423K/year** | Quantified financial exposure |
| **Churn model AUC** | 0.781 (Random Forest) | Strong predictive performance after fixing target leakage |
| **Data quality tests** | 57 automated dbt tests | Production-grade validation pipeline |

**Headline finding:** The business has a retention crisis disguised as a growth story. Over half the customer base is dormant, the top 10% of customers drive nearly half of all predicted value, and 1,841 customers are actively at risk of churning. The good news: every one of these customers is now scored, segmented, and ready for targeted intervention.

---

## 4. Data Audit & Quality

### 4.1 Dataset Overview

| Attribute | Value |
|:---|:---|
| **Source** | UCI Machine Learning Repository — Online Retail Dataset |
| **Period** | 01-Dec-2010 to 09-Dec-2011 (373 days) |
| **Raw rows** | 541,909 |
| **Columns** | 8 (InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country) |
| **Valid customers (post-clean)** | 4,338 |
| **Valid transactions (post-clean)** | ~392,000 |

### 4.2 Critical Data Quality Issues

| Finding | Count | % of Total | Severity | Resolution |
|:---|---:|---:|:---|:---|
| NULL CustomerID | 135,080 | 24.93% | 🔴 **HIGH** | Filtered out — unusable for customer analytics |
| Cancelled orders (Invoice 'C') | 9,288 | 1.71% | 🟡 MEDIUM | Filtered out — returns distort revenue |
| Quantity ≤ 0 | 10,624 | 1.96% | 🟡 MEDIUM | Filtered out — returns/cancellations |
| UnitPrice ≤ 0 | 2,517 | 0.46% | 🟡 MEDIUM | Filtered out — free items/data errors |
| UnitPrice < 0.01 (micro-values) | 4 | <0.01% | 🟡 MEDIUM | Tightened filter to ≥ 0.01 |
| Exact duplicates | 5,268 | 0.97% | 🟢 LOW | Deduplicated in Silver layer |
| Extreme quantity outliers (>10,000) | 3 | <0.01% | 🟡 MEDIUM | Flagged in Gold layer |
| Extreme price outliers (>£5,000) | 31 | <0.01% | 🟡 MEDIUM | Flagged in Gold layer |

### 4.3 Null Analysis

<p align="center">
  <img src="outputs/charts/01_null_percentage.png" alt="Null Percentage by Column" width="700"/>
</p>

> **Interpretation:** The `CustomerID` column is the only significant null concern, breaching the 20% threshold. All other columns are well below the 5% warning threshold. The 135K null CustomerID rows represent transactions that cannot be attributed to any customer — they are unusable for RFM, CLV, or churn analysis but were retained for product-level insights.

### 4.4 Distribution Analysis

<p align="center">
  <img src="outputs/charts/02_quantity_unitprice_distribution.png" alt="Quantity and UnitPrice Distributions" width="900"/>
</p>

> **Interpretation:** Both Quantity and UnitPrice are heavily right-skewed. Most transactions involve 1-10 items priced under £20, with occasional bulk orders (up to 80,995 units) and premium items (up to £38,970). This confirms a high-volume, low-margin retail model with intermittent wholesale activity.

### 4.5 Temporal & Geographic Profile

<p align="center">
  <img src="outputs/charts/03_transaction_volume_monthly.png" alt="Transaction Volume by Month" width="800"/>
</p>

> **Interpretation:** Clear seasonal pattern with Q4 spike — November 2011 peaks at ~85,000 transactions (holiday shopping). The company was in a high-growth phase, tripling volume in 9 months. December 2011 is artificially low (dataset ends 09-Dec).

<p align="center">
  <img src="outputs/charts/04_top_countries.png" alt="Top 10 Countries by Transaction Count" width="800"/>
</p>

> **Interpretation:** The dataset is 91.3% UK-centric. Geographic segmentation is only reliable for the domestic market. International expansion insights would require additional data.

### 4.6 Customer-Level Profile

<p align="center">
  <img src="outputs/charts/05_customer_spend_frequency.png" alt="Customer Spend and Frequency Distributions" width="900"/>
</p>

> **Interpretation:** Customer total spend follows an approximately log-normal distribution centered around £500-£1,000. Transaction frequency is heavily right-skewed — most customers make 1-5 purchases, with a long tail of loyalists (up to 200 transactions). The mean spend (£2,054) is 3× the median (£674), confirming extreme concentration among whale customers.

### 4.7 Correlation Analysis

<p align="center">
  <img src="outputs/charts/06_correlation_matrix.png" alt="Customer Metrics Correlation Matrix" width="600"/>
</p>

> **Interpretation:** The 0.92 correlation between `total_spend` and `total_items` signals multicollinearity risk. In downstream models, I used ratios (e.g., `avg_items_per_transaction`) instead of raw counts to avoid inflating coefficient variance.

---

## 5. Insights Deep Dive

### 5.1 Data Profile: What 541K Transactions Reveal

Before building any model, I profiled the business through its data:

- **High-growth, UK-centric DTC retailer:** 3× transaction growth and 92% UK concentration
- **Whale-driven revenue:** Top 10 customers spend £77K-£280K each. Losing one whale is catastrophic
- **One-time vs. loyalist split:** Some whales are bulk buyers (2 transactions, £168K), others are frequent purchasers (201 transactions, £144K) — these need **different retention strategies**
- **Seasonality is real:** November peak means Q4 is make-or-break for revenue

### 5.2 Customer Segmentation: The 80/20 Rule Is Real

I applied K-Means clustering (K=4, silhouette score 0.380) on log-transformed, standardized RFM features to identify natural customer groupings.

#### Model Validation

<p align="center">
  <img src="outputs/charts/07_elbow_silhouette.png" alt="Elbow Method and Silhouette Score" width="900"/>
</p>

> **Interpretation:** The elbow method shows diminishing returns after K=4, and the silhouette score peaks at K=3 (0.416) with K=4 close behind (0.380). I selected K=4 for business interpretability — it separates the critical "At Risk" segment from the broader "Average" group.

#### Segment Profiles

<p align="center">
  <img src="outputs/charts/08_rfm_segments.png" alt="Customer Segments: RFM Scatter Plots and Distribution" width="1000"/>
</p>

| Segment | Customers | Share | Avg Spend | Avg Frequency | Business Interpretation |
|:---|---:|---:|---:|---:|:---|
| **Lost / Dormant** | 2,331 | 53.7% | £389 | 2.1 | One-time or very infrequent buyers. Low engagement, minimal revenue. Candidates for win-back campaigns or cost-efficient reactivation. |
| **Average** | 1,448 | 33.4% | £1,659 | 12.3 | Moderate engagement, steady spenders. Growth potential through upselling and cross-selling. |
| **At Risk** | 559 | 12.9% | £9,978 | 42.8 | **High-value customers showing decline signals.** Previously frequent, high-spending customers with increasing recency. **#1 retention priority.** |

> **Critical insight:** The At Risk segment is only 12.9% of customers but represents the highest individual value. These are customers who *used to* be loyal but are drifting. Catching them early is the difference between retention and replacement.

#### 3D Segment Visualization

<p align="center">
  <img src="outputs/charts/09_rfm_3d.png" alt="3D RFM Customer Segmentation" width="600"/>
</p>

> **Interpretation:** The 3D plot visualizes the natural separation in RFM space. At Risk customers (orange) cluster at high frequency and monetary values but with elevated recency — the classic "was good, now fading" pattern.

### 5.3 CLV Projection: £7.7M in Predicted Value

I attempted probabilistic CLV modeling using the BG/NBD (Buy Till You Die) + Gamma-Gamma framework. However, the extreme time scales in this dataset (T up to 373 days, frequency up to 7,675) caused **convergence failure** in the BG/NBD optimizer.

**Decision:** Documented the failure transparently and fell back to an industry-standard heuristic: **AOV × (Frequency/Month) × 12 months**. This maintains methodological rigor while delivering actionable numbers.

#### CLV Distribution

<p align="center">
  <img src="outputs/charts/10_clv_analysis.png" alt="CLV Distribution and Decile Analysis" width="1000"/>
</p>

| CLV Tier | Customers | % of Base | Combined CLV | Avg CLV | Business Action |
|:---|---:|---:|---:|---:|:---|
| **VIP** | 1,149 | 26.5% | £4.96M | £4,317 | White-glove retention. Personal account management. |
| **High Value** | 1,175 | 27.1% | £1.72M | £1,463 | Targeted loyalty rewards. Exclusive access programs. |
| **Medium** | 1,028 | 23.7% | £738K | £718 | Nurture campaigns. Cross-sell opportunities. |
| **Low** | 712 | 16.4% | £251K | £353 | Cost-efficient digital engagement. |
| **Minimal** | 274 | 6.3% | £35K | £128 | Low priority. Automated drip campaigns only. |

> **Key finding:** The top 10% of customers (by CLV) account for **42.9% of total predicted value** (£3.3M). This is extreme concentration risk — the business is dangerously dependent on a small cohort of VIP customers.

### 5.4 Churn Prediction: 1,841 Customers at Risk

#### The Target Leakage Incident

> ⚠️ **This is the story every data scientist needs to tell.**

My first churn model scored **100% accuracy** and **AUC = 1.000**. Perfect. Too perfect.

**Root cause:** I had included `recency_days` as a feature — but `recency_days` was also the **definition of churn** (customers with recency > 90 days were labeled as churned). The model was essentially being asked: *"Predict if a customer hasn't bought in 90 days, given that they haven't bought in X days."*

**Fix:** Removed `recency_days` and `customer_lifespan_days` from features. Rebuilt the model.

**Result:** Realistic, trustworthy performance:

| Model | ROC-AUC | Notes |
|:---|---:|:---|
| Logistic Regression (Primary) | **0.775** | Interpretable, production-ready |
| Random Forest (Benchmark) | **0.781** | Slightly better, used for feature importance |

#### Model Performance

<p align="center">
  <img src="outputs/charts/11_roc_pr_curves.png" alt="ROC and Precision-Recall Curves" width="900"/>
</p>

> **Interpretation:** Both models significantly outperform random guessing (diagonal line). The ROC curves show strong discrimination ability across thresholds. Precision-Recall curves reveal the trade-off: at high precision (few false alarms), recall is moderate — appropriate for a retention campaign where we want to target the right customers, not just spam everyone.

#### Churn Drivers

<p align="center">
  <img src="outputs/charts/12_churn_drivers.png" alt="Churn Driver Analysis" width="900"/>
</p>

| Driver | Direction | Interpretation |
|:---|:---|:---|
| **active_months** | 🟢 Retention | Customers active across more months are far less likely to churn. The strongest protective factor. |
| **unique_products** | 🟢 Retention | Customers who buy diverse products are more engaged and stickier. |
| **spend_per_product** | 🔴 Risk | High spend per product (infrequent big purchases) correlates with churn — these may be one-time bulk buyers. |
| **engagement_score** | 🟢 Retention | Composite engagement metric — higher engagement = lower churn. |
| **items_per_transaction** | 🟢 Retention | Customers who buy more items per order show stronger loyalty. |

> **Business translation:** The best way to prevent churn is to **keep customers active across multiple months** and **encourage product diversity**. A customer who buys 5 different products over 6 months is dramatically more valuable than one who makes a single large purchase.

#### At-Risk Customer Profile

| Metric | Value |
|:---|---:|
| **At-risk customers** | 1,841 |
| **% of customer base** | 42.5% |
| **Revenue at risk** | £423,000/year |
| **Top risk factor** | Low active_months |
| **Secondary risk factor** | Low unique_products |

---

## 6. Recommendations

Prioritized the way a real budget cycle would triage them.

| Priority | Recommendation | Expected Impact | Owner |
|:---|:---|:---|:---|
| **P1 — Do First** | Launch immediate retention campaign for 559 "At Risk" customers | Prevent £423K/year revenue loss | Marketing / CRM |
| **P1 — Do First** | Implement "active_months" engagement program — monthly touchpoints, product recommendations | Address #1 churn driver | Marketing |
| **P1 — Do First** | Create VIP white-glove program for top 10% CLV customers (£3.3M at stake) | Protect 42.9% of predicted value | Customer Success |
| **P2 — Next** | Design cross-sell campaigns to increase `unique_products` per customer | Reduce churn via product diversity | Product / Marketing |
| **P2 — Next** | Segment win-back campaigns by dormancy depth — recent dormants vs. long-lost | Improve reactivation ROI | CRM |
| **P2 — Next** | A/B test subscription model for high-frequency, low-AOV customers | Stabilize recurring revenue | Product |
| **P3 — Longer** | Build automated monthly CLV and churn score refresh pipeline | Enable real-time retention decisions | Data Engineering |
| **P3 — Longer** | Investigate whale customer profiles for lookalike acquisition | Reduce CAC for high-value segments | Growth |

**The through-line:** The biggest lever isn't more acquisition spend — it's **keeping the customers you already have**, especially the 559 At Risk customers who used to be loyal and the 434 VIP customers who represent nearly half your predicted revenue.

---

## 7. Interactive Dashboard

The business intelligence layer sits on top of the Gold marts, with three integrated views:

### Dashboard Pages

| Page | Purpose | Key Visualizations |
|:---|:---|:---|
| **Overview** | Executive snapshot | KPI cards (total customers, revenue, AOV, churn rate), trend lines, segment distribution |
| **Customer Segments** | Segment deep-dive | RFM scatter plots, segment comparison tables, CLV tier breakdown, whale customer list |
| **Churn Risk** | Retention action center | Risk score distribution, at-risk customer table, driver analysis, revenue-at-risk calculator |

### Dashboard Preview

<p align="center">
  <img src="dashboard/screenshots/overview_page.png" alt="Dashboard: Overview Page" width="1000"/>
  <br><sub><em>Dashboard: Overview Page — KPI cards, transaction trends, segment distribution, CLV deciles, and risk distribution</em></sub>
</p>

<p align="center">
  <img src="dashboard/screenshots/segments_page.png" alt="Dashboard: Customer Segments Page" width="1000"/>
  <br><sub><em>Dashboard: Customer Segments Page — Interactive segment cards, RFM scatter plot, CLV tier breakdown, revenue share</em></sub>
</p>

<p align="center">
  <img src="dashboard/screenshots/churn_page.png" alt="Dashboard: Churn Risk Page" width="1000"/>
  <br><sub><em>Dashboard: Churn Risk Page — Risk alerts, ROC curves, churn drivers, and filterable at-risk customer registry</em></sub>
</p>

> **Cross-filtering enabled:** Selecting a segment on the Overview page filters all other pages. Selecting a CLV tier on the Segments page narrows the Churn Risk view to high-value at-risk customers only.

> 📁 **Interactive version:** See `dashboard/index.html` for the full interactive HTML dashboard with live charts, filters, and drill-down capabilities.

---

## 8. Tech Stack & Architecture

### 8.1 Architecture Diagram

```
Raw CSV (541K rows)
    -> PySpark ingestion -> bronze.online_retail (541K)
    -> dbt Silver cleaning -> silver.stg_transactions (~392K)
    -> dbt Gold aggregation -> gold.mart_* (3 business marts)
    -> Python modeling -> enriched tables + visualizations
    -> Power BI / HTML Dashboard -> stakeholder dashboards
```

### 8.2 Tech Stack

| Layer | Tool | Purpose |
|:---|:---|:---|
| **Compute** | Databricks Community Edition | Spark processing, Unity Catalog |
| **Storage** | Unity Catalog Volumes | Raw file ingestion (DBFS disabled) |
| **Transformation** | dbt-core + dbt-databricks | Medallion architecture, tests, docs |
| **Languages** | PySpark | Data engineering (Bronze ingestion) |
| | Python 3.11 | Data science modeling |
| | SQL | dbt models |
| **Libraries** | scikit-learn | K-Means, Logistic Regression, Random Forest |
| | lifetimes | BG/NBD + Gamma-Gamma (attempted) |
| | pandas, numpy, matplotlib, seaborn | EDA & visualization |
| **Virtual Envs** | uv | Isolated dbt + datascience environments |
| **Version Control** | Git + GitHub | Portfolio hosting |
| **BI** | Power BI / Interactive HTML | Executive dashboards |

### 8.3 Repository Structure

```
customer-churn-intelligence/
├── airflow_orchestration/
│   ├── dags/dbt_pipeline.py
│   ├── Dockerfile
│   └── requirements.txt
├── dbt_transformation/customer_churn_dbt/
│   ├── models/{staging, intermediate, marts}
│   ├── macros/generate_schema_name.sql
│   ├── tests/
│   └── dbt_project.yml
├── notebooks/
│   ├── 01_eda_pyspark.ipynb
│   ├── 02_rfm_kmeans_clustering.ipynb
│   ├── 03_clv_lifetimes.ipynb
│   └── 04_churn_prediction.ipynb
├── docs/
│   ├── data_dictionary.md
│   ├── data_audit.md
│   ├── data_quality.md
│   └── project_architecture.md
├── outputs/
│   ├── charts/
│   │   ├── 01_null_percentage.png
│   │   ├── 02_quantity_unitprice_distribution.png
│   │   ├── 03_transaction_volume_monthly.png
│   │   ├── 04_top_countries.png
│   │   ├── 05_customer_spend_frequency.png
│   │   ├── 06_correlation_matrix.png
│   │   ├── 07_elbow_silhouette.png
│   │   ├── 08_rfm_segments.png
│   │   ├── 09_rfm_3d.png
│   │   ├── 10_clv_analysis.png
│   │   ├── 11_roc_pr_curves.png
│   │   └── 12_churn_drivers.png
│   └── models/
├── dashboard/
│   ├── index.html
│   └── screenshots/
│       ├── overview_page.png
│       ├── segments_page.png
│       └── churn_page.png
├── src/
└── README.md
```

---

## 9. Data Quality & Model Rigor

### 9.1 Automated Testing

**57 dbt tests** across all models — 55 passed on first run, 2 caught edge cases that EDA missed:

| Test Type | Count | Purpose |
|:---|---:|:---|
| `not_null` | 18 | Ensure critical fields never null |
| `unique` | 6 | Prevent duplicate customer records |
| `accepted_values` | 12 | Validate categorical fields (segments, tiers, churn labels) |
| `accepted_range` | 15 | Ensure numeric fields within bounds (Quantity > 0, UnitPrice ≥ 0.01) |
| `relationships` | 6 | Enforce referential integrity across marts |

**The 2 failures:** 4 rows with UnitPrice < 0.01 (micro-values) slipped through EDA but were caught by dbt range tests. Filter tightened to ≥ 0.01.

### 9.2 Model Validation Checklist

| Check | RFM | CLV | Churn |
|:---|:---|:---|:---|
| **Convergence verified** | N/A | BG/NBD failed — documented fallback | ✅ LR converged, RF stable |
| **Cross-validation** | N/A | N/A | ✅ 5-fold CV consistent with test scores |
| **Target leakage check** | N/A | N/A | ✅ Caught and fixed (recency_days removed) |
| **Feature multicollinearity** | ✅ Addressed via ratios | N/A | ✅ VIF checked, correlated features removed |
| **Outlier treatment** | ✅ Log-transform + StandardScaler | ✅ Winsorized at 99th percentile | ✅ Robust scaling |
| **Business interpretability** | ✅ Named segments | ✅ Tier-based actionability | ✅ Coefficient signs match intuition |

### 9.3 The Target Leakage Fix: A Case Study

| Stage | Accuracy | AUC | Issue |
|:---|---:|---:|:---|
| **Initial model** | 100% | 1.000 | `recency_days` = churn definition |
| **After fix** | 68.4% | 0.775 | Realistic, trustworthy performance |
| **Random Forest benchmark** | 69.1% | 0.781 | Confirms LR results |

> **Lesson:** Perfect metrics are a warning, not a celebration. The discipline to question your own model is what separates a dashboard builder from a trusted analyst.

---

## 10. Caveats & Assumptions

- **Dataset is static (2010-2011).** A production system would refresh CLV and churn scores monthly. Seasonal effects (November holiday spike) may not generalize to other years.
- **CLV method is heuristic, not probabilistic.** BG/NBD convergence failed due to extreme time scales. The heuristic (AOV × Freq/Month × 12) is industry-standard but assumes constant purchase behavior — it will underestimate CLV for customers with accelerating engagement and overestimate for declining ones.
- **Churn definition:** Customer labeled "churned" if no purchase in 90+ days from dataset end (09-Dec-2011). This is a reasonable proxy but not ground-truth churn (some customers may have seasonal purchase patterns).
- **Geographic bias:** 91.3% UK transactions. International insights are directional only.
- **Simulated subscription data:** Monthly fee tiers and churn labels were derived from spend percentiles for modeling completeness. In a real engagement, these would come from the billing system.
- **Correlation ≠ causation:** The churn drivers (active_months, unique_products) are associative, not proven causal. A/B testing is needed to validate intervention impact.
- **This is a portfolio case study.** Built to demonstrate end-to-end capability on public data, not a live production system.

---

<p align="center">
  <sub>Built with rigor, documented with honesty, designed for impact.</sub><br>
  <sub>Questions about any specific number, modeling decision, or the EDA behind a claim — happy to walk through it.</sub>
</p>
