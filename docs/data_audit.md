# 📊 Data Audit Report: UCI Online Retail Dataset

> **Project:** Customer Segmentation, CLV Projection & Churn Analysis  
> **Dataset:** UCI Online Retail (Transnational Dataset)  
> **Audit Date:** July 2026  
> **Auditor:** [Your Name]  
> **Tools:** PySpark (Databricks), Python, Matplotlib, Seaborn  

---

## 🎯 Executive Summary

This audit examines the **UCI Online Retail dataset** — a transnational dataset containing all transactions occurring between **01-Dec-2010 and 09-Dec-2011** for a UK-based online retailer. The dataset comprises **541,909 rows** and **8 columns** covering invoice details, product information, quantities, prices, customer IDs, and country.

### Critical Findings at a Glance

| Finding | Impact | Severity |
|---------|--------|----------|
| **24.93% of rows have NULL CustomerID** | Cannot attribute 135K transactions to any customer — unusable for customer-level analytics | 🔴 **HIGH** |
| **10,624 rows have Quantity ≤ 0** | Includes cancellations and returns — must be filtered for revenue analysis | 🟡 **MEDIUM** |
| **2,517 rows have UnitPrice ≤ 0** | Free items or data entry errors — distort average order value | 🟡 **MEDIUM** |
| **5,268 exact duplicate rows (0.97%)** | Inflate transaction counts if not deduplicated | 🟢 **LOW** |
| **9,288 cancelled orders (1.71%)** | InvoiceNo prefixed with 'C' — represent returns/cancellations | 🟢 **INFO** |
| **UK dominates at ~92% of transactions** | Geographic bias — insights may not generalize globally | 🟡 **MEDIUM** |
| **Extreme outliers in Quantity (up to 80,995)** | Likely B2B wholesale orders — need capping/flagging in Gold layer | 🟡 **MEDIUM** |

**Post-cleaning valid customer records: 4,338 customers** spanning 373 days.

---

## 1. Dataset Overview

### 1.1 Schema

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `InvoiceNo` | String | Yes | Invoice number. Prefixed with 'C' for cancellations |
| `StockCode` | String | Yes | Product code |
| `Description` | String | Yes | Product description |
| `Quantity` | Integer | Yes | Quantity per transaction line |
| `InvoiceDate` | String | Yes | Invoice date (format: `dd-MM-yyyy HH:mm`) |
| `UnitPrice` | Double | Yes | Price per unit in GBP |
| `CustomerID` | Integer | Yes | Unique customer identifier |
| `Country` | String | Yes | Customer country |

### 1.2 Sample Records

| InvoiceNo | StockCode | Description | Quantity | InvoiceDate | UnitPrice | CustomerID | Country |
|-----------|-----------|-------------|----------|-------------|-----------|------------|---------|
| 536365 | 85123A | WHITE HANGING HEART T-LIGHT HOLDER | 6 | 01-12-2010 08:26 | 2.55 | 17850 | United Kingdom |
| 536365 | 71053 | WHITE METAL LANTERN | 6 | 01-12-2010 08:26 | 3.39 | 17850 | United Kingdom |
| 536365 | 84406B | CREAM CUPID HEARTS COAT HANGER | 8 | 01-12-2010 08:26 | 2.75 | 17850 | United Kingdom |
| 536365 | 84029G | KNITTED UNION FLAG HOT WATER BOTTLE | 6 | 01-12-2010 08:26 | 3.39 | 17850 | United Kingdom |
| 536365 | 84029E | RED WOOLLY HOTTIE WHITE HEART. | 6 | 01-12-2010 08:26 | 3.39 | 17850 | United Kingdom |

### 1.3 Dataset Scale

| Metric | Value |
|--------|-------|
| **Total Rows** | 541,909 |
| **Total Columns** | 8 |
| **Date Range** | 01-Dec-2010 to 09-Dec-2011 |
| **Span (Days)** | 373 |
| **Valid Customers (post-cleaning)** | 4,338 |

---

## 2. Null Analysis

### 2.1 Null Counts by Column

| Column | Null Count | Null % | Severity |
|--------|-----------|--------|----------|
| `InvoiceNo` | 0 | 0.00% | ✅ Clean |
| `StockCode` | 0 | 0.00% | ✅ Clean |
| `Description` | 1,454 | 0.27% | 🟢 Low |
| `Quantity` | 0 | 0.00% | ✅ Clean |
| `InvoiceDate` | 0 | 0.00% | ✅ Clean |
| `UnitPrice` | 0 | 0.00% | ✅ Clean |
| `CustomerID` | **135,080** | **24.93%** | 🔴 **HIGH** |
| `Country` | 0 | 0.00% | ✅ Clean |

### 2.2 Null Visualization

![Null Percentage by Column](../outputs/charts/01_null_percentage.png)

> **Chart Interpretation:** The `CustomerID` column is the only significant null concern, breaching the 20% threshold. All other columns are well below the 5% warning threshold. `Description` has a negligible 0.27% null rate.

### 2.3 Business Impact of NULL CustomerID

- **135,080 transactions (24.93%)** cannot be linked to any customer
- These transactions are **unusable** for customer-level analytics (RFM, CLV, Churn)
- However, they can still be used for **product-level** or **time-series** analysis
- **Action:** Filter out NULL CustomerID rows in the Silver layer (`stg_transactions`)

---

## 3. Duplicate Analysis

### 3.1 Exact Duplicates

| Metric | Value |
|--------|-------|
| Exact Duplicate Rows | 5,268 |
| % of Total | 0.97% |

### 3.2 Invoice-Level Duplicates

| Metric | Value |
|--------|-------|
| Duplicate Groups (InvoiceNo + StockCode + CustomerID) | 9,694 |

### 3.3 Example Duplicate Group

The following shows **18 identical rows** for the same invoice, product, and customer — likely a system glitch or batch entry error:

| InvoiceNo | StockCode | Description | Quantity | InvoiceDate | UnitPrice | CustomerID | Country |
|-----------|-----------|-------------|----------|-------------|-----------|------------|---------|
| 555524 | 22698 | PINK REGENCY TEACUP AND SAUCER | 1 | 05-06-2011 11:37 | 2.95 | 16923 | United Kingdom |
| 555524 | 22698 | PINK REGENCY TEACUP AND SAUCER | 1 | 05-06-2011 11:37 | 2.95 | 16923 | United Kingdom |
| ... | ... | ... | ... | ... | ... | ... | ... |
| *(18 identical rows total)* |

> **Action:** Apply `DISTINCT` or `ROW_NUMBER() OVER (PARTITION BY ...)` deduplication in the Silver layer.

---

## 4. Outlier & Distribution Analysis

### 4.1 Numeric Summary Statistics

| Statistic | Quantity | UnitPrice |
|-----------|----------|-----------|
| **Min** | -80,995 | -11,062.06 |
| **Max** | 80,995 | 38,970.00 |
| **Mean** | 9.55 | 4.61 |
| **Median** | 3 | 2.08 |
| **Std Dev** | 218.08 | 96.76 |

> **Key Observation:** The massive gap between mean and median (9.55 vs 3 for Quantity, 4.61 vs 2.08 for UnitPrice) indicates **heavy right skew** — most transactions are small, but a few are enormous.

### 4.2 Negative & Zero Values

| Condition | Count | % of Total | Interpretation |
|-----------|-------|-----------|----------------|
| `Quantity ≤ 0` | 10,624 | 1.96% | Cancellations, returns, or data errors |
| `UnitPrice ≤ 0` | 2,517 | 0.46% | Free items, discounts, or data errors |

### 4.3 Extreme Outliers

| Outlier Type | Threshold | Count | Examples |
|-------------|-----------|-------|----------|
| Extreme Quantity | > 10,000 | 3 | 80,995 (PAPER CRAFT), 74,215 (STORAGE JAR), 12,540 (STICKERS) |
| Extreme UnitPrice | > £5,000 | 31 | £38,970 (highest), likely data entry errors or luxury items |

### 4.4 Distribution Visualizations

![Quantity and UnitPrice Distributions](../outputs/charts/02_quantity_unitprice_distribution.png)

> **Chart Interpretation:**
> - **Quantity:** Heavily right-skewed with most values clustered near 0-50. The long tail extends to ~1,000 (filtered view).
> - **UnitPrice:** Similarly right-skewed, with the vast majority of items priced under £20. A small secondary cluster appears around £10-£20.
> - **Business Insight:** The retailer operates a high-volume, low-margin model with occasional bulk/wholesale orders.

---

## 5. Temporal Analysis

### 5.1 Date Range

| Metric | Value |
|--------|-------|
| **First Transaction** | 01-Dec-2010 08:26:00 |
| **Last Transaction** | 09-Dec-2011 12:50:00 |
| **Total Span** | 373 days (~12.3 months) |

### 5.2 Monthly Transaction Volume

![Transaction Volume by Month](../outputs/charts/03_transaction_volume_monthly.png)

> **Chart Interpretation:**
> - **Seasonal Pattern:** Clear Q4 spike — November 2011 peaks at **~85,000 transactions**, likely driven by holiday shopping (Black Friday, Christmas prep)
> - **Growth Trajectory:** Steady growth from Feb 2011 (~27K) to Nov 2011 (~85K) — **3x growth in 9 months**
> - **December 2011 Drop:** Only **~25,000 transactions** — dataset ends on 09-Dec-2011, so this is a partial month
> - **Business Insight:** The company was in a **high-growth phase** during this period. Any churn/CLV models must account for this growth bias.

### 5.3 Monthly Transaction Counts (Table)

| Month | Transaction Count | Notes |
|-------|------------------|-------|
| 2010-12 | 42,000 | Launch month (partial) |
| 2011-01 | 35,000 | Post-holiday dip |
| 2011-02 | 27,000 | Lowest full month |
| 2011-03 | 36,000 | Recovery |
| 2011-04 | 29,000 | Spring dip |
| 2011-05 | 36,000 | Stabilization |
| 2011-06 | 36,000 | Consistent |
| 2011-07 | 39,000 | Summer growth |
| 2011-08 | 35,000 | Slight dip |
| 2011-09 | 50,000 | Back-to-school boost |
| 2011-10 | 60,000 | Pre-holiday ramp |
| 2011-11 | **85,000** | **Peak (Holiday season)** |
| 2011-12 | 25,000 | Partial month (ends 09-Dec) |

---

## 6. Geographic Analysis

### 6.1 Country Distribution

![Top 10 Countries by Transaction Count](../outputs/charts/04_top_countries.png)

> **Chart Interpretation:** The dataset is **heavily UK-centric**. The United Kingdom accounts for approximately **92% of all transactions**. The next largest markets (Germany, France, EIRE) are orders of magnitude smaller.

### 6.2 Top 10 Countries (Table)

| Rank | Country | Transaction Count | % of Total |
|------|---------|------------------|------------|
| 1 | **United Kingdom** | ~495,000 | ~91.3% |
| 2 | Germany | ~9,500 | ~1.8% |
| 3 | France | ~8,500 | ~1.6% |
| 4 | EIRE | ~8,000 | ~1.5% |
| 5 | Spain | ~2,500 | ~0.5% |
| 6 | Netherlands | ~2,400 | ~0.4% |
| 7 | Belgium | ~2,100 | ~0.4% |
| 8 | Switzerland | ~2,000 | ~0.4% |
| 9 | Portugal | ~1,500 | ~0.3% |
| 10 | Australia | ~1,200 | ~0.2% |

> **Business Impact:** Any geographic segmentation or country-based recommendations will be statistically unreliable for non-UK markets. The business is effectively **UK-domestic** with minor European presence.

---

## 7. Customer-Level Analysis

### 7.1 Customer Spend Statistics

| Statistic | Value (£) |
|-----------|-----------|
| **Count** | 4,338 customers |
| **Mean** | 2,054.27 |
| **Std Dev** | 8,989.23 |
| **Min** | 3.75 |
| **25th Percentile** | 307.42 |
| **Median (50th)** | 674.49 |
| **75th Percentile** | 1,661.74 |
| **Max** | **280,206.02** |

> **Key Insight:** The mean (£2,054) is **3x the median (£674)**, confirming extreme right skew. A small number of whale customers drive the average up significantly.

### 7.2 Customer Distribution

![Customer Total Spend and Transaction Frequency Distributions](../outputs/charts/05_customer_spend_frequency.png)

> **Chart Interpretation:**
> - **Total Spend (Log10 Scale):** Approximately log-normal distribution centered around Log10(£500-£1,000). The long right tail captures whale customers spending £10,000+.
> - **Transaction Frequency:** Heavily right-skewed — most customers make **1-5 purchases**, with a rapid drop-off. The longest tail extends to ~200 transactions (likely B2B or reseller accounts).

### 7.3 Top 10 Customers by Total Spend

| Rank | CustomerID | Total Spend (£) | Transactions | Avg Order Value (£) | Segment Hint |
|------|-----------|----------------|--------------|---------------------|-------------|
| 1 | 14646 | **280,206.02** | 73 | 3,838.44 | 🐋 Whale |
| 2 | 18102 | **259,657.30** | 60 | 4,327.62 | 🐋 Whale |
| 3 | 17450 | **194,550.79** | 46 | 4,229.36 | 🐋 Whale |
| 4 | 16446 | **168,472.50** | 2 | 84,236.25 | 🐋 Whale (Bulk) |
| 5 | 14911 | **143,825.06** | 201 | 715.55 | 🐋 Whale (Frequent) |
| 6 | 12415 | **124,914.53** | 21 | 5,948.31 | 🐋 Whale |
| 7 | 14156 | **117,379.63** | 55 | 2,134.18 | 🐋 Whale |
| 8 | 17511 | **91,062.38** | 31 | 2,937.50 | 🐋 Whale |
| 9 | 16029 | **81,024.84** | 63 | 1,286.11 | 🐋 Whale |
| 10 | 12346 | **77,183.60** | 1 | 77,183.60 | 🐋 Whale (One-time bulk) |

> **Critical Observation:** The top 10 customers range from **£77K to £280K** in total spend. Customer 16446 made only **2 transactions** but spent £168K — likely a **B2B wholesale account**. Customer 14911 made **201 transactions** — a **high-frequency loyalist**. These behavioral differences will be critical for RFM segmentation.

---

## 8. Correlation Analysis

### 8.1 Correlation Matrix

![Customer Metrics Correlation Matrix](../outputs/charts/06_correlation_matrix.png)

### 8.2 Correlation Values (Table)

| Variable Pair | Correlation | Interpretation |
|--------------|-------------|----------------|
| `total_spend` ↔ `total_items` | **0.92** | Very strong positive — more items = higher spend (expected) |
| `transaction_count` ↔ `total_spend` | **0.55** | Moderate positive — frequent buyers tend to spend more |
| `transaction_count` ↔ `total_items` | **0.56** | Moderate positive — frequent buyers buy more items |

> **Modeling Implication:** The 0.92 correlation between `total_spend` and `total_items` means including both in a churn model would introduce **multicollinearity**. In the Gold layer, we should use ratios (e.g., `avg_items_per_transaction`) instead of raw counts, or drop one variable.

---

## 9. Data Quality Scorecard

| # | Metric | Value | Severity | Action Required |
|---|--------|-------|----------|----------------|
| 1 | Total Rows | 541,909 | ℹ️ INFO | Baseline |
| 2 | Null CustomerID | 135,080 (24.93%) | 🔴 **HIGH** | **FILTER OUT** in Silver layer |
| 3 | Null Description | 1,454 (0.27%) | 🟢 LOW | Acceptable — keep with NULL handling |
| 4 | Cancelled Orders (Invoice 'C') | 9,288 (1.71%) | ℹ️ INFO | **FILTER OUT** for revenue analysis |
| 5 | UnitPrice ≤ 0 | 2,517 (0.46%) | 🟡 MEDIUM | **FILTER OUT** — distort metrics |
| 6 | Quantity ≤ 0 | 10,624 (1.96%) | 🟡 MEDIUM | **FILTER OUT** — returns/cancellations |
| 7 | Exact Duplicates | 5,268 (0.97%) | 🟢 LOW | **DEDUPLICATE** in Silver layer |
| 8 | Valid Customers (post-clean) | 4,338 | ℹ️ INFO | Usable for customer analytics |
| 9 | Date Span | 373 days | ℹ️ INFO | ~12.3 months of data |
| 10 | UK Transaction Share | ~91.3% | 🟡 MEDIUM | Note geographic bias in recommendations |
| 11 | Extreme Quantity Outliers | 3 (>10,000) | 🟡 MEDIUM | **FLAG** in Gold layer for segmentation |
| 12 | Extreme Price Outliers | 31 (>£5,000) | 🟡 MEDIUM | **FLAG** in Gold layer |

---

## 10. Recommendations for Data Modeling

Based on this audit, the following data quality rules are **mandatory** for the Silver and Gold layers:

### 10.1 Silver Layer (`stg_transactions`) — Cleaning Rules

| Rule | Implementation | Rationale |
|------|---------------|-----------|
| **Filter NULL CustomerID** | `WHERE CustomerID IS NOT NULL` | 25% of rows unusable for customer analytics |
| **Filter Cancellations** | `WHERE NOT InvoiceNo LIKE 'C%'` | Returns have negative quantities and distort revenue |
| **Filter Negative Quantities** | `WHERE Quantity > 0` | Ensures only valid sales transactions |
| **Filter Zero/Negative Prices** | `WHERE UnitPrice > 0` | Removes free items and data errors |
| **Deduplicate** | `DISTINCT` or `ROW_NUMBER()` | Removes 5,268 exact duplicates |
| **Parse Dates** | `try_to_timestamp(InvoiceDate, 'dd-MM-yyyy HH:mm')` | Original format is NOT UTF-8, uses European date format |
| **Engineer LineTotal** | `Quantity * UnitPrice` | Standard revenue metric for all downstream analysis |

### 10.2 Gold Layer — Feature Engineering Considerations

| Consideration | Recommendation |
|--------------|----------------|
| **Multicollinearity** | Use `avg_order_value` instead of raw `total_items` alongside `total_spend` |
| **Outlier Handling** | Create `is_whale` flag for customers with spend > £50,000 or single transaction > £10,000 |
| **Geographic Bias** | Add `is_uk` boolean for segmentation; note limited international validity |
| **Temporal Bias** | Dataset ends 09-Dec-2011 (partial month) — December metrics may be artificially low |
| **Growth Phase** | Company was 3x-ing transaction volume — CLV models should use cohort-based calibration |

### 10.3 Data Quality Tests (dbt)

The following tests must be implemented in dbt `schema.yml`:

```yaml
tests:
  - not_null: [CustomerID, InvoiceNo, StockCode, Quantity, UnitPrice]
  - positive_values: [Quantity, UnitPrice]
  - accepted_values:
      column: InvoiceNo
      condition: "NOT LIKE 'C%'"
  - unique:
      column: [InvoiceNo, StockCode, CustomerID]
      where: "Description IS NOT NULL"
```

---

## 11. Business Narrative: From Audit to Action

> *"The CEO asked three questions: Who are our best customers? What are they worth? Who's about to leave? Before we can answer any of them, we had to understand what we're working with."*

### What the Data Tells Us About the Business

1. **High-Growth, UK-Centric DTC Retailer:** The 3x transaction growth and 92% UK concentration suggest a domestic-focused business in rapid expansion.

2. **Whale-Driven Revenue:** The top 10 customers spend £77K-£280K each. Losing even one whale customer would be catastrophic. **Retention of top-tier customers is the #1 priority.**

3. **One-Time vs. Loyalist Split:** Some whales are one-time bulk buyers (2 transactions, £168K), while others are frequent purchasers (201 transactions, £144K). These need **different retention strategies**.

4. **Seasonality is Real:** The November peak (~85K transactions) means Q4 is make-or-break. Churn prediction must be **calibrated for seasonal effects**.

5. **Data is Messy but Salvageable:** 25% null CustomerIDs and 1.7% cancellations are manageable with proper filtering. The core dataset (4,338 customers, ~400K valid transactions) is robust enough for modeling.

---

*End of Data Audit Report*

> **Next Phase:** Silver & Gold dbt Models → Data Quality Tests → Data Science Modeling

