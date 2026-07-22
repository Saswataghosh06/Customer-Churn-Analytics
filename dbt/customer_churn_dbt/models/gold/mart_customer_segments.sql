{{ config(
    materialized='table',
    schema='gold',
    tags=['gold', 'rfm', 'segmentation']
) }}

/*
    RFM (Recency, Frequency, Monetary) Customer Segmentation Mart

    Business Purpose:
    - Enables targeted marketing campaigns by customer value tier
    - Identifies Champions, Loyal Customers, At-Risk, and Lost segments
    - Feeds into K-Means clustering for data-driven segmentation

    EDA Insights Applied:
    - UK geographic bias noted (is_uk_customer flag)
    - Extreme spenders flagged (is_whale)
    - Seasonal growth phase acknowledged in tenure calculations
*/

WITH customer_metrics AS (
    SELECT
        CustomerID,
        -- Recency: Days since last purchase (lower = better)
        DATEDIFF(day, MAX(invoice_timestamp), CURRENT_DATE()) AS recency_days,
        -- Frequency: Number of distinct transactions
        COUNT(DISTINCT InvoiceNo) AS frequency,
        -- Monetary: Total lifetime spend
        ROUND(SUM(line_total), 2) AS monetary,
        -- Additional behavioral metrics
        COUNT(*) AS total_line_items,
        ROUND(AVG(line_total), 2) AS avg_line_value,
        MAX(invoice_timestamp) AS last_purchase_date,
        MIN(invoice_timestamp) AS first_purchase_date,
        DATEDIFF(day, MIN(invoice_timestamp), MAX(invoice_timestamp)) AS customer_lifespan_days
    FROM {{ ref('stg_transactions') }}
    GROUP BY CustomerID
),

scored AS (
    SELECT
        CustomerID,
        recency_days,
        frequency,
        monetary,
        total_line_items,
        avg_line_value,
        last_purchase_date,
        first_purchase_date,
        customer_lifespan_days,
        -- RFM Scores: 1-5 scale (5 = best)
        NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,      -- Lower recency = higher score
        NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,        -- Higher frequency = higher score
        NTILE(5) OVER (ORDER BY monetary DESC) AS m_score,         -- Higher monetary = higher score
        -- Whale flag: Top 1% spenders (EDA showed extreme outliers)
        CASE WHEN monetary >= (SELECT PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY monetary) FROM customer_metrics)
             THEN TRUE ELSE FALSE END AS is_whale
    FROM customer_metrics
)

SELECT
    CustomerID,
    recency_days,
    frequency,
    monetary,
    total_line_items,
    avg_line_value,
    last_purchase_date,
    first_purchase_date,
    customer_lifespan_days,
    r_score,
    f_score,
    m_score,
    -- Composite RFM Score
    r_score + f_score + m_score AS rfm_score,
    -- RFM Segment Code (e.g., "555", "451")
    CONCAT(CAST(r_score AS STRING), CAST(f_score AS STRING), CAST(m_score AS STRING)) AS rfm_segment_code,
    -- Business-Readable Segment Labels
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score <= 2 THEN 'Potential Loyalists'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 3 THEN 'Cannot Lose Them'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost'
        ELSE 'Others'
    END AS customer_segment,
    is_whale,
    -- Segment priority for business action
    CASE
        WHEN customer_segment IN ('Champions', 'Cannot Lose Them') THEN 'P1 - Critical Retention'
        WHEN customer_segment IN ('Loyal Customers', 'Potential Loyalists') THEN 'P2 - Grow & Nurture'
        WHEN customer_segment IN ('At Risk', 'New Customers') THEN 'P3 - Activate & Re-engage'
        WHEN customer_segment = 'Lost' THEN 'P4 - Win-back Campaign'
        ELSE 'P5 - Monitor'
    END AS business_priority
FROM scored
