# Data Dictionary

**Project:** Customer Churn Intelligence Platform
**Catalog:** `customer_churn_project` (Databricks Unity Catalog)
**Schemas:** `bronze` → `silver` → `gold`
**Last updated:** derived directly from `sources.yml`, `schema.yml`, and the dbt model SQL in the current codebase. No fields below are inferred beyond what is explicitly stated; where the generation logic of a field could not be confirmed from source, it is marked **Unconfirmed** rather than guessed.

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
Customer-level aggregates joined with **synthetic** subscription attributes, used to enable ML feature engineering that the raw UCI dataset does not natively support (the UCI dataset has no subscription or churn label of its own).

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
| `subscription_tier` | STRING | **Synthetic** field. One of `Basic`, `Standard`, `Premium`, `Enterprise`. **Unconfirmed:** the exact assignment rule (e.g., percentile-of-spend cut-off vs. random draw) is not present in the available SQL, notebooks, or docs supplied for this project, so it is not stated here as fact. |
| `monthly_fee` | DOUBLE | **Synthetic** field, ≥ 0. **Unconfirmed** generation rule — same caveat as above. |
| `churn_label` | INT (0/1) | **Confirmed** rule (stated directly in `sources.yml`): `1` if the customer has been inactive for more than 90 days, `0` otherwise. |

> **Honesty note:** `subscription_tier` and `monthly_fee` are documented here as synthetic/simulated exactly as the source config describes them. Their precise generation formula was not recoverable from the files provided, so this dictionary states that plainly instead of presenting an invented rule as fact.

---

## 2. Silver Layer (Cleaned)

### 2.1 `silver.stg_transactions`
Cleaned transaction data. Applies EDA-informed filters — see `data_quality.md` for the full rule list and row counts removed at each step.

| Column | Type | Description | dbt Tests |
|---|---|---|---|
| `InvoiceNo` | STRING | Clean invoice number (no `C`-prefixed cancellations) | `not_null` |
| `StockCode` | STRING | Product code | `not_null` |
| `Description` | STRING | Product description | — |
| `Quantity` | INT | Valid quantity (> 0) | `not_null`, range ≥ 1 |
| `invoice_timestamp` | TIMESTAMP | Parsed from `dd-MM-yyyy HH:mm` | `not_null` |
| `UnitPrice` | DOUBLE | Valid unit price (≥ 0.01) | `not_null`, range ≥ 0.01 |
| `CustomerID` | STRING | Non-null customer identifier | `not_null` |
| `Country` | STRING | Customer country | — |
| `line_total` | DOUBLE | Engineered: `Quantity × UnitPrice`, rounded to 2 dp | `not_null`, range ≥ 0.01 |
| `is_extreme_quantity` | BOOLEAN | `TRUE` if `Quantity > 10,000` (EDA outlier flag) | — |
| `is_extreme_price` | BOOLEAN | `TRUE` if `UnitPrice > 5,000` (EDA outlier flag) | — |
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
| `recency_days` | INT | Days since last purchase, calculated as `DATEDIFF(day, MAX(invoice_timestamp), CURRENT_DATE())`. **Known technical caveat:** this mart calculates recency against the *query execution date*, not the dataset's observation end date (09-Dec-2011) used elsewhere in the pipeline. See `data_quality.md` §4 for the full explanation and why it does not affect segment validity. | `not_null` |
| `frequency` | INT | Number of distinct transactions (`InvoiceNo`) | `not_null`, range ≥ 1 |
| `monetary` | DOUBLE | Total lifetime spend, rounded to 2 dp | `not_null`, range ≥ 0 |
| `total_line_items` | INT | Count of all transaction line items | — |
| `avg_line_value` | DOUBLE | Average value per line item | — |
| `last_purchase_date` | TIMESTAMP | Most recent invoice timestamp | — |
| `first_purchase_date` | TIMESTAMP | Earliest invoice timestamp | — |
| `customer_lifespan_days` | INT | Days between first and last purchase | — |
| `r_score` | INT (1–5) | Recency score via `NTILE(5) OVER (ORDER BY recency_days ASC)`. **Confirmed logic bug:** `NTILE` assigns bucket 1 to the smallest `recency_days` (most recent buyers) and bucket 5 to the largest (most dormant) — the opposite of the code comment ("Lower recency = higher score") and the intent documented in `schema.yml` ("5 = most recent"). Correcting this requires `ORDER BY recency_days DESC`. See `data_quality.md` §4.3 for confirmation via actual cluster output. | range 1–5 |
| `f_score` | INT (1–5) | Frequency score via `NTILE(5) OVER (ORDER BY frequency DESC)`. **Same bug, inverted direction:** bucket 1 goes to the *highest*-frequency customers, not the lowest, contradicting "5 = most frequent." Correcting this requires `ORDER BY frequency ASC`. | range 1–5 |
| `m_score` | INT (1–5) | Monetary score via `NTILE(5) OVER (ORDER BY monetary DESC)`. **Same bug:** bucket 1 goes to the *highest* spenders, contradicting "5 = highest spend." Correcting this requires `ORDER BY monetary ASC`. | range 1–5 |
| `rfm_score` | INT (3–15) | `r_score + f_score + m_score`. Inherits the inversion above — a low `rfm_score` currently indicates a *better* customer, not a worse one, under the current SQL. | — |
| `rfm_segment_code` | STRING | Concatenated RFM digits, e.g. `"555"`. Inherits the same inversion. | — |
| `customer_segment` | STRING | Rule-based label: Champions, Loyal Customers, New Customers, Potential Loyalists, At Risk, Cannot Lose Them, Lost, Others. **Confirmed mislabeled in the current build** as a direct consequence of the scoring inversion above — verified against `01_rfm_kmeans_clustering.ipynb` output, where the cluster with the highest recency_days (5,595 days), lowest frequency (1.38), and lowest monetary value (£388.43) of any cluster is mode-labeled `"Champions"` by this column. `dbt`'s `accepted_values` test only validates the label spelling, not correctness of assignment, so this passes all current tests. **This column is not the source of the business segments reported elsewhere in this project** — those come from K-Means clustering on the raw `recency_days`/`frequency`/`monetary` values in the notebooks, which is unaffected by this bug. | `accepted_values` (8 labels) |
| `is_whale` | BOOLEAN | `TRUE` if `monetary` ≥ 99th percentile of all customers | — |
| `business_priority` | STRING | P1–P5 action priority mapped from `customer_segment` — **inherits the same mislabeling**, since it is derived directly from the inverted `customer_segment` field. | `not_null` |

### 3.2 `gold.mart_clv_projections` — CLV Modeling Inputs
Formatted for the `lifetimes` library (BG/NBD + Gamma-Gamma convention). Excludes one-time buyers (`frequency = 0`).

| Column | Type | Description | dbt Tests |
|---|---|---|---|
| `CustomerID` | STRING | Unique customer identifier | `not_null`, `unique` |
| `frequency` | INT | Repeat purchases only (`count of purchases − 1`) | `not_null`, range ≥ 1 |
| `recency` | INT | Days between first and last purchase | `not_null`, range ≥ 0 |
| `T` | INT | Days between first purchase and the dataset's max invoice date (09-Dec-2011) — deliberately **not** `CURRENT_DATE()`, to avoid a multi-year distortion | `not_null`, range ≥ 0 |
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
| `recency_days` | INT | Days since last purchase, calculated against the dataset's max invoice date (correct convention) | `not_null`, range ≥ 0 |
| `customer_lifespan_days` | INT | Days between first and last purchase | — |
| `active_months` | INT | Count of distinct calendar months with a purchase | — |
| `avg_items_per_order` | DOUBLE | `COUNT(*) / COUNT(DISTINCT InvoiceNo)` | — |
| `has_high_value_order` | BOOLEAN | `TRUE` if any single line > £1,000 | — |
| `has_bulk_purchase` | BOOLEAN | `TRUE` if any single line quantity > 100 | — |
| `spend_per_transaction` | DOUBLE | `total_spend / total_transactions` | — |
| `items_per_transaction` | DOUBLE | `total_items / total_transactions` | — |
| `spend_per_product` | DOUBLE | `total_spend / unique_products` | — |
| `purchase_regularity` | DOUBLE | `(active_months / customer_lifespan_days) × 30` | — |
| `tier_encoded` | INT (1–4) | Numeric encoding of `subscription_tier` | range 1–4 |
| `is_whale` | BOOLEAN | `TRUE` if `total_spend` ≥ £50,000 | — |
| `is_inactive_90d` | BOOLEAN | `TRUE` if `recency_days` > 90 | — |
| `is_inactive_60d` | BOOLEAN | `TRUE` if `recency_days` > 60 | — |
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
| `cluster_business_name` | STRING | Business label: Lost / Dormant, Average, At Risk (3 unique labels mapped across 4 numeric clusters — two clusters both map to "Lost / Dormant") |

### 4.2 `gold.mart_clv_projections_enriched`
Adds CLV model outputs to `mart_clv_projections`.

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
| `risk_tier` | STRING | Safe (<20%) / Low Risk (20–40%) / Medium Risk (40–60%) / High Risk (60–80%) / Critical Risk (80%+) |

---

## 5. Field-Level Business Rules Reference

| Rule | Where Applied | Exact Logic |
|---|---|---|
| Churn definition | `bronze.customers_simulated` → all downstream marts | `recency_days > 90` ⇒ `churn_label = 1` |
| RFM segment assignment | `mart_customer_segments` | Rule-based on `r_score`/`f_score`/`m_score` thresholds (see model SQL) — **but the underlying scores are computed with an inverted `NTILE` sort direction; see §4 above and `data_quality.md` §4.3** |
| Whale flag (segments mart) | `mart_customer_segments` | `monetary` ≥ 99th percentile of all customers |
| Whale flag (churn mart) | `mart_churn_risk` | `total_spend` ≥ £50,000 (fixed threshold, not percentile-based — note this differs in method from the segments mart's whale flag) |
| CLV modeling eligibility | `mart_clv_projections` | Excludes customers with `frequency = 0` (one-time buyers) — 4,338 → 4,267 customers modeled (71 excluded) |