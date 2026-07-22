{{ config(
    materialized='table',
    schema='gold',
    tags=['gold', 'clv', 'lifetimes']
) }}

/*
    Customer Lifetime Value (CLV) Projection Mart
    
    Business Purpose:
    - Provides inputs for probabilistic CLV models (BG/NBD + Gamma-Gamma)
    - Enables CFO to set acquisition budget per customer segment
    - Identifies high-CLV customers for retention investment
    
    Model Requirements (lifetimes library format):
    - frequency: Number of repeat purchases (count - 1)
    - recency: Time between first and last purchase (in days)
    - T: Time between first purchase and end of observation period (in days)
    - monetary_value: Average transaction value for repeat purchases only
    
    EDA Insights Applied:
    - Observation period ends at max(InvoiceDate) from dataset, not CURRENT_DATE
      (Dataset spans Dec 2010 - Dec 2011, so using CURRENT_DATE would distort T)
    - Cancellations already filtered in Silver layer
*/

WITH observation_period AS (
    -- Dataset's actual end date (09-Dec-2011) — using CURRENT_DATE would skew T by 15+ years
    SELECT MAX(invoice_timestamp) AS end_date FROM {{ ref('stg_transactions') }}
),

customer_purchases AS (
    SELECT
        CustomerID,
        invoice_timestamp,
        line_total,
        -- Identify repeat vs first purchase
        ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY invoice_timestamp) AS purchase_num
    FROM {{ ref('stg_transactions') }}
),

customer_stats AS (
    SELECT
        CustomerID,
        MIN(invoice_timestamp) AS first_purchase,
        MAX(invoice_timestamp) AS last_purchase,
        -- frequency: repeat purchases only (lifetimes convention)
        COUNT(*) - 1 AS frequency,
        -- monetary_value: average of repeat purchases only
        ROUND(AVG(CASE WHEN purchase_num > 1 THEN line_total END), 2) AS monetary_value
    FROM customer_purchases
    GROUP BY CustomerID
)

SELECT
    c.CustomerID,
    c.frequency,
    -- recency: time between first and last purchase (days)
    DATEDIFF(day, c.first_purchase, c.last_purchase) AS recency,
    -- T: time between first purchase and end of observation period (days)
    DATEDIFF(day, c.first_purchase, o.end_date) AS T,
    c.monetary_value,
    c.first_purchase,
    c.last_purchase,
    o.end_date AS observation_end_date,
    -- Business-friendly metrics
    CASE 
        WHEN c.frequency = 0 THEN 'One-time Buyer'
        WHEN c.frequency BETWEEN 1 AND 4 THEN 'Occasional'
        WHEN c.frequency BETWEEN 5 AND 10 THEN 'Regular'
        WHEN c.frequency > 10 THEN 'Frequent'
    END AS purchase_frequency_tier,
    -- FIX: All branches must return the same type (STRING)
    CASE
        WHEN c.monetary_value IS NULL THEN 'No Repeat Purchases'
        WHEN c.monetary_value < 10 THEN 'Low Value'
        WHEN c.monetary_value < 50 THEN 'Medium Value'
        WHEN c.monetary_value < 200 THEN 'High Value'
        ELSE 'Premium Value'
    END AS value_tier
FROM customer_stats c
CROSS JOIN observation_period o
WHERE c.frequency > 0  -- Exclude one-time buyers from CLV modeling (no repeat behavior to predict)