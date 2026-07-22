# dbt Project: Customer Churn & CLV Analytics

## Overview
This dbt project implements a **Medallion Architecture** (Bronze -> Silver -> Gold) for a Customer Segmentation, CLV Projection, and Churn Analysis pipeline.

## Architecture

```
Bronze (Databricks Tables)
├── bronze.online_retail          <- Raw CSV ingestion
└── bronze.customers_simulated    <- Simulated subscription layer

Silver (dbt Models)
├── stg_transactions              <- Cleaned transactions (EDA-informed filters)
└── stg_customers                 <- Cleaned customer profiles

Gold (dbt Models / Business Marts)
├── mart_customer_segments        <- RFM scores & segments for K-Means
├── mart_clv_projections          <- CLV inputs for lifetimes library
└── mart_churn_risk               <- ML features for churn prediction
```

## Setup Instructions

### 1. Configure Connection
Your profile is already set up at `C:\Users\HP\.dbt\profiles.yml`.

### 2. Install Dependencies
```bash
cd "D:\Customer Churn Project\dbt\customer_churn_dbt"
dbt deps
```

### 3. Test Connection
```bash
dbt debug
```

### 4. Run Models
```bash
dbt run
```

### 5. Run Tests
```bash
dbt test
```

### 6. Generate Documentation
```bash
dbt docs generate
dbt docs serve
```

## Data Quality
- 15+ automated tests across all models
- EDA-informed filtering (nulls, cancellations, negatives, duplicates)
- Accepted values, range checks, uniqueness constraints
- Outlier flags for extreme quantities and prices

## Business Marts
| Mart | Purpose | Downstream Use |
|------|---------|---------------|
| `mart_customer_segments` | RFM segmentation | K-Means clustering, marketing campaigns |
| `mart_clv_projections` | CLV model inputs | lifetimes BG/NBD + Gamma-Gamma |
| `mart_churn_risk` | ML feature engineering | scikit-learn Logistic Regression / Random Forest |
