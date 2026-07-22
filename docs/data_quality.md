# Data Quality Report

## Overview

This document tracks data quality across the entire pipeline: from raw ingestion through dbt transformations to final model outputs. It demonstrates a production-grade approach to data validation.

---

## Phase 1: Raw Data Quality (EDA Findings)

### Dataset: UCI Online Retail
- **Total Rows:** 541,909
- **Columns:** 8
- **Date Range:** 01-Dec-2010 to 09-Dec-2011
- **Encoding:** ISO-8859-1
- **Date Format:** dd-MM-yyyy HH:mm

### Quality Issues Identified

| Issue | Count | Percentage | Severity | Action |
|-------|-------|------------|----------|--------|
| NULL CustomerID | 135,080 | 24.93% | HIGH | Filter out in Silver |
| NULL Description | 1,454 | 0.27% | LOW | Acceptable |
| Cancelled Orders (Invoice 'C') | 9,288 | 1.71% | INFO | Filter out in Silver |
| Quantity <= 0 | 10,624 | 1.96% | MEDIUM | Filter out in Silver |
| UnitPrice <= 0 | 2,517 | 0.46% | MEDIUM | Filter out in Silver |
| UnitPrice < 0.01 (micro-values) | 4 | <0.01% | MEDIUM | Tighten filter to >= 0.01 |
| Exact Duplicates | 5,268 | 0.97% | LOW | DISTINCT in Silver |
| Extreme Quantity (>10,000) | 3 | <0.01% | MEDIUM | Flag in Gold |
| Extreme UnitPrice (>5,000) | 31 | <0.01% | MEDIUM | Flag in Gold |

### Geographic Bias
- UK: ~91.3% of transactions
- Next 9 countries combined: <9%
- **Impact:** Geographic segmentation unreliable for non-UK markets

### Temporal Bias
- Dataset ends 09-Dec-2011 (partial month)
- Nov 2011 peak: ~85,000 transactions (holiday season)
- **Impact:** December metrics artificially low; seasonal effects present

---

## Phase 2: dbt Data Quality (Automated Tests)

### Test Results Summary

| Run | Tests | Passed | Failed | Notes |
|-----|-------|--------|--------|-------|
| Initial | 57 | 55 | 2 | 4 rows with UnitPrice < 0.01 caught |
| After Fix | 57 | 57 | 0 | Filter tightened to >= 0.01 |

### Tests by Model

#### silver.stg_transactions
- not_null: InvoiceNo, StockCode, Quantity, invoice_timestamp, UnitPrice, CustomerID, line_total
- accepted_range: Quantity >= 1, UnitPrice >= 0.01, line_total >= 0.01

#### silver.stg_customers
- not_null + unique: CustomerID
- accepted_values: subscription_tier in [Basic, Standard, Premium, Enterprise]
- accepted_range: monthly_fee >= 0
- accepted_values: churn_label in [0, 1]

#### gold.mart_customer_segments
- not_null + unique: CustomerID
- accepted_range: r_score, f_score, m_score in [1, 5]
- accepted_values: customer_segment in [Champions, Loyal Customers, New Customers, Potential Loyalists, At Risk, Cannot Lose Them, Lost, Others]

#### gold.mart_clv_projections
- not_null + unique: CustomerID
- accepted_range: frequency >= 1, recency >= 0, T >= 0, monetary_value >= 0

#### gold.mart_churn_risk
- not_null + unique: CustomerID
- accepted_values: churn_label in [0, 1]
- accepted_range: total_transactions >= 1, total_spend >= 0, recency_days >= 0

---

## Phase 3: Model Data Quality

### RFM K-Means Clustering
- **Input:** 4,338 customers
- **Features:** recency_days, frequency, monetary (log-transformed)
- **Scaling:** StandardScaler
- **Validation:** Elbow method + Silhouette score (K=4, score=0.380)
- **Output:** 4 clusters with business names

### CLV Projection
- **Method:** Robust heuristic (AOV x Freq/Month x 12)
- **BG/NBD Attempt:** Failed convergence due to extreme time scales (T up to 373 days, frequency up to 7,675)
- **Fallback:** Industry-standard heuristic with documented assumptions
- **Validation:** No inf/NaN values, decile distribution reasonable

### Churn Prediction
- **Initial Issue:** Target leakage (recency_days = churn definition)
- **Initial Metrics:** 100% accuracy, AUC=1.000 (unrealistic)
- **Fix:** Removed recency_days and customer_lifespan_days
- **Final Metrics:** LR AUC=0.775, RF AUC=0.781 (realistic)
- **Cross-Validation:** 5-fold CV consistent with test scores

---

## Data Quality Maturity Scorecard

| Dimension | EDA | dbt Tests | Model Validation | Maturity |
|-----------|-----|-----------|------------------|----------|
| Null Detection | Manual | Automated | N/A | Production-Ready |
| Range Validation | Visual | Automated | N/A | Production-Ready |
| Uniqueness | Group-by | Automated | N/A | Production-Ready |
| Referential Integrity | N/A | Cross-model refs | N/A | Production-Ready |
| Accepted Values | N/A | Automated | N/A | Production-Ready |
| Target Leakage | N/A | N/A | Caught & Fixed | Production-Ready |
| Model Convergence | N/A | N/A | Monitored & Documented | Production-Ready |
| Documentation | Markdown | dbt docs | Notebook comments | Production-Ready |

---

## Recommendations for Production

1. **Add dbt source freshness tests** on bronze.online_retail to detect stale data
2. **Implement Great Expectations** for more complex validation rules
3. **Add data lineage tracking** using dbt exposures for BI tools
4. **Set up dbt Cloud CI/CD** for automated testing on pull requests
5. **Monitor model drift** in churn predictions (retrain monthly)
6. **Add anomaly detection** for sudden spikes in cancellations or returns
