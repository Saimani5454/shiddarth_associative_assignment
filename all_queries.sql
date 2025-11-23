-- Yearly Growth Analysis Query
WITH yearly AS (
    SELECT
        strftime('%Y', DATE) AS year,
        SUM("TOTAL VALUE_INR") AS total_value,
        SUM("DUTY PAID_INR") AS total_duty,
        SUM("Grand Total") AS total_grand
    FROM trade_data
    GROUP BY strftime('%Y', DATE)
)
SELECT
    a.year,
    a.total_value,
    b.total_value AS prev_year_value,
    ROUND(((a.total_value - b.total_value) / b.total_value) * 100.0, 2) AS YoY_Total_Value_Growth,

    a.total_duty,
    b.total_duty AS prev_year_duty,
    ROUND(((a.total_duty - b.total_duty) / b.total_duty) * 100.0, 2) AS YoY_Duty_Growth,

    a.total_grand,
    b.total_grand AS prev_year_grand,
    ROUND(((a.total_grand - b.total_grand) / b.total_grand) * 100.0, 2) AS YoY_Grand_Total_Growth

FROM yearly a
LEFT JOIN yearly b
ON CAST(a.year AS INTEGER) = CAST(b.year AS INTEGER) + 1
ORDER BY a.year;


-- ==================================================

-- HSN Code Contribution Query
WITH ranked AS (
    SELECT
        "HS CODE" AS hsn_code,
        SUM("Grand Total") AS total_value,
        ROW_NUMBER() OVER (ORDER BY SUM("Grand Total") DESC) AS rn
    FROM trade_data
    GROUP BY "HS CODE"
),
bucketed AS (
    SELECT
        CASE WHEN rn <= 25 THEN hsn_code ELSE 'OTHERS' END AS category,
        total_value
    FROM ranked
)
SELECT
    category,
    SUM(total_value) AS total_value,
    ROUND(SUM(total_value) * 100.0 / (SELECT SUM("Grand Total") FROM trade_data), 2) AS contribution_percent
FROM bucketed
GROUP BY category
ORDER BY total_value DESC;


-- ==================================================

-- Entity Activity Query
WITH activity AS (
    SELECT
        IEC AS entity_identifier,
        MIN(strftime('%Y', DATE)) AS first_year,
        MAX(strftime('%Y', DATE)) AS last_year
    FROM trade_data
    GROUP BY IEC
)
SELECT
    entity_identifier,
    first_year,
    last_year,
    CASE
        WHEN last_year = '2025' THEN 'ACTIVE'
        ELSE 'CHURNED'
    END AS entity_status
FROM activity
ORDER BY entity_status, entity_identifier;


-- ==================================================

-- Model-Year Summary Query
SELECT
    Model AS model,
    strftime('%Y', DATE) AS year,
    SUM(QUANTITY) AS total_quantity,
    AVG("UNIT PRICE_INR") AS avg_unit_price_inr,
    AVG("UNIT PRICE_USD") AS avg_unit_price_usd
FROM processed_trade_data_enriched
GROUP BY Model, strftime('%Y', DATE)
ORDER BY model, year;


-- ==================================================

-- Model-Specific Price Analysis Query
SELECT
    Model AS model,
    AVG("UNIT PRICE_INR") AS avg_price_inr,
    MIN("UNIT PRICE_INR") AS min_price_inr,
    MAX("UNIT PRICE_INR") AS max_price_inr,
    SUM(QUANTITY) AS total_quantity,
    COUNT(*) AS shipment_count
FROM processed_trade_data_enriched
WHERE Model IS NOT NULL
GROUP BY Model
ORDER BY model, avg_price_inr ASC;


-- ==================================================

-- Capacity Analysis Query
SELECT
    "Capacity/Spec" AS capacity,
    SUM(QUANTITY) AS total_quantity,
    SUM("TOTAL VALUE_INR") AS total_import_value,
    ROUND((SUM("TOTAL VALUE_INR") * 100) / (SELECT SUM("TOTAL VALUE_INR") FROM processed_trade_data_enriched), 2) AS percentage_contribution
FROM processed_trade_data_enriched
WHERE "Capacity/Spec" IS NOT NULL
GROUP BY "Capacity/Spec"
ORDER BY total_quantity DESC;


-- ==================================================

-- Landed Cost Per Unit Query
SELECT
    Model AS model,
    NULL AS supplier,
    "Capacity/Spec" AS capacity,
    QUANTITY AS quantity,
    Grand_Total AS total_cost,
    CAST(Grand_Total AS REAL) / NULLIF(CAST(QUANTITY AS REAL),0) AS raw_landed_cost_per_unit,
    ROUND(CAST(Grand_Total AS REAL) / NULLIF(CAST(QUANTITY AS REAL),0),2) AS landed_cost_per_unit
FROM processed_trade_data_enriched;


-- ==================================================

-- Trade Model Economics View Query
DROP VIEW IF EXISTS trade_model_economics;
CREATE VIEW trade_model_economics AS
SELECT
    DATE AS shipment_date,
    strftime('%Y', DATE) AS year,
    Model AS model,
    "Capacity/Spec" AS capacity,
    NULL AS supplier,
    QUANTITY AS quantity,
    "Standardized Unit" AS unit,
    "UNIT PRICE_INR" AS unit_price_inr,
    "UNIT PRICE_USD" AS parsed_price_usd,
    Grand_Total AS grand_total,
    ROUND(CAST(Grand_Total AS REAL) / NULLIF(CAST(QUANTITY AS REAL),0), 2) AS landed_cost_per_unit,
    duty_pct
FROM processed_trade_data_enriched;


-- ==================================================

