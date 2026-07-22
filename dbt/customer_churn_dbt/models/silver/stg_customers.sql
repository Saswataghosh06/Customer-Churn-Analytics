{{ config(
    materialized='table',
    schema='silver',
    tags=['silver', 'customers']
) }}

/*
    Simulated subscription customer data from Bronze layer.
    Minimal transformation — primarily type casting and standardization.
*/

SELECT
    CustomerID,
    first_purchase_date,
    last_purchase_date,
    transaction_count,
    total_spend,
    total_items,
    unique_products,
    country,
    recency_days,
    tenure_days,
    subscription_tier,
    monthly_fee,
    churn_label,
    -- Data quality flag
    CASE WHEN Country = 'United Kingdom' THEN TRUE ELSE FALSE END AS is_uk_customer
FROM {{ source('bronze', 'customers_simulated') }}
