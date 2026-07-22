{{ config(
    materialized='table',
    schema='silver',
    tags=['silver', 'transactions']
) }}

/*
    EDA-Informed Cleaning Rules Applied:
    1. FILTER: Exclude rows where CustomerID IS NULL (24.93% of raw data)
    2. FILTER: Exclude cancelled orders (InvoiceNo starts with 'C') — 9,288 rows
    3. FILTER: Exclude rows with Quantity <= 0 — 10,624 rows (returns/errors)
    4. FILTER: Exclude rows with UnitPrice <= 0 — 2,517 rows (free items/errors)
    5. DEDUPLICATE: Remove exact duplicate rows — 5,268 rows
    6. PARSE: InvoiceDate from dd-MM-yyyy HH:mm format (ISO-8859-1 encoding)
    7. ENGINEER: LineTotal = Quantity * UnitPrice
    8. FLAG: Add data quality indicators for downstream auditing
*/

WITH deduplicated AS (
    SELECT DISTINCT
        InvoiceNo,
        StockCode,
        Description,
        Quantity,
        InvoiceDate,
        UnitPrice,
        CustomerID,
        Country
    FROM {{ source('bronze', 'online_retail') }}
),

parsed AS (
    SELECT
        InvoiceNo,
        StockCode,
        Description,
        Quantity,
        -- Critical: Date format is dd-MM-yyyy HH:mm (European format, NOT UTF-8)
        try_to_timestamp(InvoiceDate, 'dd-MM-yyyy HH:mm') AS invoice_timestamp,
        UnitPrice,
        CustomerID,
        Country
    FROM deduplicated
)

SELECT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    invoice_timestamp,
    UnitPrice,
    CustomerID,
    Country,
    -- Core engineered metric
    ROUND(Quantity * UnitPrice, 2) AS line_total,
    -- Data quality flags for audit trail
    CASE WHEN Quantity > 10000 THEN TRUE ELSE FALSE END AS is_extreme_quantity,
    CASE WHEN UnitPrice > 5000 THEN TRUE ELSE FALSE END AS is_extreme_price,
    CASE WHEN Country = 'United Kingdom' THEN TRUE ELSE FALSE END AS is_uk_customer
FROM parsed
WHERE
    -- EDA Rule 1: CustomerID must be present for customer-level analytics
    CustomerID IS NOT NULL
    -- EDA Rule 2: Exclude cancellations (InvoiceNo prefixed with 'C')
    AND InvoiceNo NOT LIKE 'C%'
    -- EDA Rule 3: Valid quantities only
    AND Quantity > 0
    -- EDA Rule 4: Valid prices only (>= 0.01 to exclude micro-values caught by dbt tests)
    AND UnitPrice >= 0.01
    -- EDA Rule 6: Date must parse successfully
    AND invoice_timestamp IS NOT NULL