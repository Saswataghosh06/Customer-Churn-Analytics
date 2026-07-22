{{ config(
    materialized='table',
    schema='gold',
    tags=['gold', 'churn', 'ml-features']
) }}

/*
    Churn Risk Prediction Feature Mart

    Business Purpose:
    - Provides ML-ready features for churn prediction models
    - Enables proactive retention campaigns before customers leave
    - Combines transaction behavior, subscription simulation, and engagement signals

    EDA Insights Applied:
    - total_spend and total_items are highly correlated (0.92) — use ratios instead
    - UK geographic bias captured via is_uk_customer flag
    - Extreme outliers flagged (is_whale) to prevent model skew
    - Seasonal growth acknowledged — recency calculated from dataset end, not current date
*/

WITH transaction_features AS (
    SELECT
        CustomerID,
        -- Core transaction metrics
        COUNT(DISTINCT InvoiceNo) AS total_transactions,
        ROUND(SUM(line_total), 2) AS total_spend,
        SUM(Quantity) AS total_items,
        COUNT(DISTINCT StockCode) AS unique_products,
        ROUND(AVG(line_total), 2) AS avg_line_value,
        ROUND(SUM(line_total) / COUNT(DISTINCT InvoiceNo), 2) AS avg_order_value,
        -- Temporal features
        DATEDIFF(day, MAX(invoice_timestamp), (SELECT MAX(invoice_timestamp) FROM {{ ref('stg_transactions') }})) AS recency_days,
        DATEDIFF(day, MIN(invoice_timestamp), MAX(invoice_timestamp)) AS customer_lifespan_days,
        -- Engagement features
        COUNT(DISTINCT DATE_TRUNC('month', invoice_timestamp)) AS active_months,
        ROUND(COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT InvoiceNo), 0), 2) AS avg_items_per_order,
        -- Behavioral flags
        MAX(CASE WHEN line_total > 1000 THEN 1 ELSE 0 END) AS has_high_value_order,
        MAX(CASE WHEN Quantity > 100 THEN 1 ELSE 0 END) AS has_bulk_purchase
    FROM {{ ref('stg_transactions') }}
    GROUP BY CustomerID
),

enriched AS (
    SELECT
        c.CustomerID,
        -- Subscription features (simulated)
        c.first_purchase_date,
        c.last_purchase_date,
        c.tenure_days,
        c.subscription_tier,
        c.monthly_fee,
        c.churn_label,
        c.country,
        c.is_uk_customer,
        -- Transaction features
        t.total_transactions,
        t.total_spend,
        t.total_items,
        t.unique_products,
        t.avg_line_value,
        t.avg_order_value,
        t.recency_days,
        t.customer_lifespan_days,
        t.active_months,
        t.avg_items_per_order,
        t.has_high_value_order,
        t.has_bulk_purchase,
        -- Engineered ratios (avoid multicollinearity from EDA finding)
        ROUND(t.total_spend / NULLIF(t.total_transactions, 0), 2) AS spend_per_transaction,
        ROUND(t.total_items * 1.0 / NULLIF(t.total_transactions, 0), 2) AS items_per_transaction,
        ROUND(t.total_spend / NULLIF(t.unique_products, 0), 2) AS spend_per_product,
        ROUND(t.active_months * 1.0 / NULLIF(t.customer_lifespan_days, 0) * 30, 2) AS purchase_regularity,
        -- Tier encoding for ML models
        CASE 
            WHEN c.subscription_tier = 'Basic' THEN 1
            WHEN c.subscription_tier = 'Standard' THEN 2
            WHEN c.subscription_tier = 'Premium' THEN 3
            WHEN c.subscription_tier = 'Enterprise' THEN 4
        END AS tier_encoded,
        -- Outlier flags (EDA: extreme quantities/spend exist)
        CASE WHEN t.total_spend >= 50000 THEN TRUE ELSE FALSE END AS is_whale,
        -- Risk signals
        CASE WHEN t.recency_days > 90 THEN TRUE ELSE FALSE END AS is_inactive_90d,
        CASE WHEN t.recency_days > 60 THEN TRUE ELSE FALSE END AS is_inactive_60d,
        -- Composite engagement score (higher = more engaged)
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
