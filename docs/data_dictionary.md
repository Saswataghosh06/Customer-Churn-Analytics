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

**Catalog:** `customer_churn_project` (Databricks Unity Catalog)  
**Schemas:** `bronze` → `silver` → `gold`  
**Last updated:** derived directly from `sources.yml`, `schema.yml`, and the dbt model SQL in the current codebase. No fields below are inferred beyond what is explicitly stated.

---

## 1. Bronze Layer (Raw / Landed Data)

### 1.1 `bronze.online_retail`
Raw UCI Online Retail transactions ingested from CSV via a Unity Catalog Volume.

| Column | Inferred Type | Description |
|---|---|---|
| `InvoiceNo` | STRING | Invoice number. Prefixed with `C` for cancellations/returns. |
| `StockCode` | STRING | Product code. |
| `Description` | STRING | Product description. ~0.27% NULL. |
| `Quantity` | INT | Quantity per transaction line. Negative values indicate returns. |
| `InvoiceDate` | STRING | Invoice timestamp, raw format `dd-MM-yyyy HH:mm` (source file encoding ISO-8859-1). |
| `UnitPrice` | DOUBLE | Price per unit in GBP. Zero/negative values indicate errors or free items. |
| `CustomerID` | STRING | Unique customer identifier. NULL for ~24.93% of rows — unusable for customer-level analytics. |
| `Country` | STRING | Customer country. United Kingdom accounts for ~91–92% of rows. |

### 1.2 `bronze.customers_simulated`
Customer-level aggregates joined with **synthetic** subscription attributes, used to enable ML feature engineering that the raw UCI dataset does not natively support.

| Column | Inferred Type | Description |
|---|---|---|
| `CustomerID` | STRING | Unique customer identifier. |
| `first_purchase_date` | TIMESTAMP | Customer's first transaction date. |
| `last_purchase_date` | TIMESTAMP | Customer's last transaction date. |
| `transaction_count` | INT | Total number of transactions. |
| `total_spend` | DOUBLE | Total lifetime spend. |
| `total_items` | INT | Total items purchased. |
| `unique_products` | INT | Number of unique products purchased. |
| `country` | STRING | Customer country. |
| `recency_days` | INT | Days since last purchase. |
| `tenure_days` | INT | Days between first and last purchase. |
| `subscription_tier` | STRING | **Synthetic** field. One of `Basic`, `Standard`, `Premium`, `Enterprise`. |
| `monthly_fee` | DOUBLE | **Synthetic** field, ≥ 0. |
| `churn_label` | INT (0/1) | **Confirmed** rule (stated in `sources.yml`): `1` if the customer has been inactive for more than 90 days, `0` otherwise. |

&gt; **Note:** `subscription_tier` and `monthly_fee` are synthetic fields layered onto the real UCI transaction data. `churn_label` is generated via the documented rule above. All downstream models treat these as simulated attributes.

---

## 2. Silver Layer (Cleaned)

### 2.1 `silver.stg_transactions`
Cleaned transaction data. Applies EDA-informed filters — see `data_quality.md` for the full rule list and row counts removed at each step.

| Column | Type | Description | dbt Tests |
|---|---|---|---|
| `InvoiceNo` | STRING | Clean invoice number (no `C`-prefixed cancellations) | `not_null` |
| `StockCode` | STRING | Product code | `not_null` |
| `Description` | STRING | Product description | — |
| `Quantity` | INT | Valid quantity (&gt; 0) | `not_null`, range ≥ 1 |
| `invoice_timestamp` | TIMESTAMP | Parsed from `dd-MM-yyyy HH:mm` | `not_null` |
| `UnitPrice` | DOUBLE | Valid unit price (≥ 0.01) | `not_null`, range ≥ 0.01 |
| `CustomerID` | STRING | Non-null customer identifier | `not_null` |
| `Country` | STRING | Customer country | — |
| `line_total` | DOUBLE | Engineered: `Quantity × UnitPrice`, rounded to 2 dp | `not_null`, range ≥ 0.01 |
| `is_extreme_quantity` | BOOLEAN | `TRUE` if `Quantity &gt; 10,000` (EDA outlier flag) | — |
| `is_extreme_price` | BOOLEAN | `TRUE` if `UnitPrice &gt; 5,000` (EDA outlier flag) | — |
| `is_uk_customer` | BOOLEAN | `TRUE` if `Country = 'United Kingdom'` | — |

### 2.2 `silver.stg_customers`
Minimal transformation of `bronze.customers_simulated` — primarily type standardization and a UK flag.

| Column | Type | Description | dbt Tests |
|---|---|---|---|
| `CustomerID` | STRING | Unique customer identifier | `not_null`, `unique` |
| `first_purchase_date` | TIMESTAMP | Passed through from Bronze | — |
| `last_purchase_date` | TIMESTAMP | Passed through from Bronze | — |
| `transaction_count` | INT | Passed through from Bronze | — |
| `total_spend` | DOUBLE | Passed through from Bronze | — |
| `total_items` | INT | Passed through from Bronze | — |
| `unique_products` | INT | Passed through from Bronze | — |
| `country` | STRING | Passed through from Bronze | — |
| `recency_days` | INT | Passed through from Bronze | — |
| `tenure_days` | INT | Passed through from Bronze | — |
| `subscription_tier` | STRING | Passed through from Bronze | `accepted_values`: Basic/Standard/Premium/Enterprise |
| `monthly_fee` | DOUBLE | Passed through from Bronze | `not_null`, range ≥ 0 |
| `churn_label` | INT (0/1) | Passed through from Bronze | `not_null`, `accepted_values`: [0,1] |
| `is_uk_customer` | BOOLEAN | Engineered: `TRUE` if `Country = 'United Kingdom'` | — |

---

## 3. Gold Layer (Business Marts)

### 3.1 `gold.mart_customer_segments` — RFM Segmentation
Feeds the K-Means clustering step in `01_rfm_kmeans_clustering.ipynb`.

| Column | Type | Description | dbt Tests |
|---|---|---|---|
| `CustomerID` | STRING | Unique customer identifier | `not_null`, `unique` |
| `recency_days` | INT | Days since last purchase, calculated against the dataset's observation end date (09-Dec-2011) for consistency across all marts | `not_null` |
| `frequency` | INT | Number of distinct transactions (`InvoiceNo`) | `not_null`, range ≥ 1 |
| `monetary` | DOUBLE | Total lifetime spend, rounded to 2 dp | `not_null`, range ≥ 0 |
| `total_line_items` | INT | Count of all transaction line items | — |
| `avg_line_value` | DOUBLE | Average value per line item | — |
| `last_purchase_date` | TIMESTAMP | Most recent invoice timestamp | — |
| `first_purchase_date` | TIMESTAMP | Earliest invoice timestamp | — |
| `customer_lifespan_days` | INT | Days between first and last purchase | — |
| `r_score` | INT (1–5) | Recency score via `NTILE(5) OVER (ORDER BY recency_days DESC)`. Score 5 = most recent (best), score 1 = most dormant. | range 1–5 |
| `f_score` | INT (1–5) | Frequency score via `NTILE(5) OVER (ORDER BY frequency ASC)`. Score 5 = highest frequency (best), score 1 = lowest. | range 1–5 |
| `m_score` | INT (1–5) | Monetary score via `NTILE(5) OVER (ORDER BY monetary ASC)`. Score 5 = highest spend (best), score 1 = lowest. | range 1–5 |
| `rfm_score` | INT (3–15) | `r_score + f_score + m_score`. Higher = better customer. | — |
| `rfm_segment_code` | STRING | Concatenated RFM digits, e.g. `"555"` for best customers. | — |
| `customer_segment` | STRING | Rule-based label: Champions, Loyal Customers, New Customers, Potential Loyalists, At Risk, Cannot Lose Them, Lost, Others. | `accepted_values` (8 labels) |
| `is_whale` | BOOLEAN | `TRUE` if `monetary` ≥ 99th percentile of all customers | — |
| `business_priority` | STRING | P1–P5 action priority mapped from `customer_segment` | `not_null` |

### 3.2 `gold.mart_clv_projections` — CLV Heuristic Estimate Inputs
Formatted for the `lifetimes` library convention (BG/NBD + Gamma-Gamma). Excludes one-time buyers (`frequency = 0`).

| Column | Type | Description | dbt Tests |
|---|---|---|---|
| `CustomerID` | STRING | Unique customer identifier | `not_null`, `unique` |
| `frequency` | INT | Repeat purchases only (`count of purchases − 1`) | `not_null`, range ≥ 1 |
| `recency` | INT | Days between first and last purchase | `not_null`, range ≥ 0 |
| `T` | INT | Days between first purchase and the dataset's max invoice date (09-Dec-2011) | `not_null`, range ≥ 0 |
| `monetary_value` | DOUBLE | Average line value across repeat purchases only | `not_null`, range ≥ 0 |
| `first_purchase` | TIMESTAMP | First transaction timestamp | — |
| `last_purchase` | TIMESTAMP | Last transaction timestamp | — |
| `observation_end_date` | TIMESTAMP | Dataset's max invoice timestamp, used as the modeling cut-off | — |
| `purchase_frequency_tier` | STRING | One-time Buyer / Occasional / Regular / Frequent, bucketed from `frequency` | — |
| `value_tier` | STRING | No Repeat Purchases / Low / Medium / High / Premium Value, bucketed from `monetary_value` | — |

### 3.3 `gold.mart_churn_risk` — ML Feature Mart
ML-ready feature set for churn prediction. Ratios used in place of raw counts to address the 0.92 `total_spend`–`total_items` correlation found in EDA.

| Column | Type | Description | dbt Tests |
|---|---|---|---|
| `CustomerID` | STRING | Unique customer identifier | `not_null`, `unique` |
| `first_purchase_date`, `last_purchase_date`, `tenure_days` | — | Passed through from `stg_customers` | — |
| `subscription_tier`, `monthly_fee` | — | Passed through from `stg_customers` | — |
| `churn_label` | INT (0/1) | Target variable | `not_null`, `accepted_values`: [0,1] |
| `country`, `is_uk_customer` | — | Passed through from `stg_customers` | — |
| `total_transactions` | INT | `COUNT(DISTINCT InvoiceNo)` | `not_null`, range ≥ 1 |
| `total_spend` | DOUBLE | `SUM(line_total)` | `not_null`, range ≥ 0 |
| `total_items` | INT | `SUM(Quantity)` | — |
| `unique_products` | INT | `COUNT(DISTINCT StockCode)` | — |
| `avg_line_value` | DOUBLE | `AVG(line_total)` | — |
| `avg_order_value` | DOUBLE | `SUM(line_total) / COUNT(DISTINCT InvoiceNo)` | — |
| `recency_days` | INT | Days since last purchase, calculated against the dataset's max invoice date (09-Dec-2011) | `not_null`, range ≥ 0 |
| `customer_lifespan_days` | INT | Days between first and last purchase | — |
| `active_months` | INT | Count of distinct calendar months with a purchase | — |
| `avg_items_per_order` | DOUBLE | `COUNT(*) / COUNT(DISTINCT InvoiceNo)` | — |
| `has_high_value_order` | BOOLEAN | `TRUE` if any single line &gt; £1,000 | — |
| `has_bulk_purchase` | BOOLEAN | `TRUE` if any single line quantity &gt; 100 | — |
| `spend_per_transaction` | DOUBLE | `total_spend / total_transactions` | — |
| `items_per_transaction` | DOUBLE | `total_items / total_transactions` | — |
| `spend_per_product` | DOUBLE | `total_spend / unique_products` | — |
| `purchase_regularity` | DOUBLE | `(active_months / customer_lifespan_days) × 30` | — |
| `tier_encoded` | INT (1–4) | Numeric encoding of `subscription_tier` | range 1–4 |
| `is_whale` | BOOLEAN | `TRUE` if `total_spend` ≥ £50,000 | — |
| `is_inactive_90d` | BOOLEAN | `TRUE` if `recency_days` &gt; 90 | — |
| `is_inactive_60d` | BOOLEAN | `TRUE` if `recency_days` &gt; 60 | — |
| `engagement_score` | DOUBLE | Composite: `0.3×transactions + 0.3×(spend/100) + 0.2×unique_products + 0.2×active_months` | `not_null` |

---

## 4. Enriched Gold Marts (Notebook Outputs)

These tables are written back to Unity Catalog from the modeling notebooks and extend the marts above.

### 4.1 `gold.mart_customer_segments_enriched` (+ `gold.cluster_mapping`)
Adds K-Means outputs to `mart_customer_segments`.

| Column | Type | Description |
|---|---|---|
| *(all columns from `mart_customer_segments`)* | — | Unchanged |
| `cluster` | INT (0–3) | K-Means cluster assignment, K=4 |
| `cluster_business_name` | STRING | Business label: Lost / Dormant, Loyal / Average, Cannot Lose Them (3 unique labels mapped across 4 numeric clusters — two clusters both map to "Lost / Dormant") |

### 4.2 `gold.mart_clv_projections_enriched`
Adds CLV heuristic outputs to `mart_clv_projections`.

| Column | Type | Description |
|---|---|---|
| *(all columns from `mart_clv_projections`)* | — | Unchanged |
| `clv_12m` | DOUBLE | Projected 12-month CLV via heuristic: `AOV × (Frequency/Month) × 12` |
| `predicted_purchases_6m` | DOUBLE | Predicted purchase count over 6 months |
| `probability_alive` | DOUBLE (0–1) | Heuristic-derived probability the customer is still active |
| `clv_tier` | STRING | Minimal / Low / Medium / High / VIP Value, bucketed from `clv_12m` |

### 4.3 `gold.mart_churn_risk_scored`
Adds churn model outputs to `mart_churn_risk`.

| Column | Type | Description |
|---|---|---|
| *(all columns from `mart_churn_risk`)* | — | Unchanged |
| `churn_risk_score` | DOUBLE (0–1) | Predicted churn probability (Random Forest, the selected best model) |
| `risk_tier` | STRING | Safe (&lt;20%) / Low Risk (20–40%) / Medium Risk (40–60%) / High Risk (60–80%) / Critical Risk (80%+) |

---

## 5. Field-Level Business Rules Reference

| Rule | Where Applied | Exact Logic |
|---|---|---|
| Churn definition | `bronze.customers_simulated` → all downstream marts | `recency_days &gt; 90` ⇒ `churn_label = 1` |
| RFM segment assignment | `mart_customer_segments` | Rule-based on `r_score`/`f_score`/`m_score` thresholds (see model SQL) |
| Whale flag (segments mart) | `mart_customer_segments` | `monetary` ≥ 99th percentile of all customers |
| Whale flag (churn mart) | `mart_churn_risk` | `total_spend` ≥ £50,000 (fixed threshold, not percentile-based) |
| CLV modeling eligibility | `mart_clv_projections` | Excludes customers with `frequency = 0` (one-time buyers) — 4,338 → 4,267 customers modeled (71 excluded) |
