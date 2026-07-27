--yearly aggregation query (filtered to Sales) with transaction count and total value first, 
--get that working and sanity-checked, then layer in LAG for YoY
SELECT * FROM transactions
LIMIT(10)-- Helper 
SELECT 
COUNT(*) AS total_rows,
COUNT(actual_worth) AS actual_worth_rows,
COUNT(actual_worth_capped) AS actual_worth_capped_rows
FROM transactions
-- Confirmed no null values that cause wrong statisical values 

-- yearly aggregation, filtered to Sales:
CREATE OR REPLACE VIEW yearly_total AS
SELECT 
year,
COUNT(*) AS txn_count, 
ROUND(SUM(actual_worth),2) AS total_value
FROM transactions
WHERE lower(trim(trans_group)) = 'sales' AND year BETWEEN 1998 AND 2025 -- not including 2026 Beacuse data Is incomplete and Geoplolitical Shock factor 
--wont allow to annualize which is possible under normal condition 
GROUP BY year
ORDER BY year
--
-- Decided to make 1998 as  starting date since before that there is only very low count of tranaction which can disort the analysis
--------------------------------------------------------------------------------------

WITH yearly AS (
  SELECT 
    year, 
    COUNT(*) AS txn_count, 
    SUM(actual_worth) AS total_value
  FROM transactions
  WHERE lower(trim(trans_group)) = 'sales' 
    AND year BETWEEN 1998 AND 2025
  GROUP BY year
),
with_lag AS (
  SELECT 
    year,
    txn_count,
    total_value,
    LAG(txn_count) OVER (ORDER BY year) AS prev_txn_count,
    LAG(total_value) OVER (ORDER BY year) AS prev_year_value
  FROM yearly
)
SELECT 
  year,
  txn_count,
  total_value,
  prev_year_value,
  ROUND(
    (total_value - prev_year_value) / prev_year_value * 100, 2
  ) AS yoy_value_growth_pct,
  ROUND(
    (txn_count - prev_txn_count)::numeric / prev_txn_count * 100, 2
  ) AS yoy_txn_growth_pct
FROM with_lag
ORDER BY year;
-------------------------------------
CREATE VIEW kpi AS 
WITH agg AS(
SELECT 
ROUND(SUM(actual_worth)::NUMERIC,2) AS net_transaction_value,
COUNT(*) AS total_txn
FROM transactions
WHERE LOWER(TRIM(trans_group)) ='sales' AND year BETWEEN 1998 AND 2025
)
SELECT 
net_transaction_value,
ROUND((net_transaction_value / total_txn)::NUMERIC,2) AS avg_transaction_Value,
total_txn
FROM agg;
-----------------------------------------------------------------
CREATE OR REPLACE VIEW kpi_2 AS(
SELECT 
year,
ROUND(SUM(actual_worth_capped)::NUMERIC,2) AS net_transaction_value
FROM transactions 
WHERE LOWER(TRIM(trans_group)) ='sales' AND year BETWEEN 1998 AND 2025
GROUP BY year
ORDER BY net_transaction_value DESC
LIMIT 1
)
-----------------------------------------------------------------------
CREATE VIEW Total_unq_area AS
SELECT
    COUNT(DISTINCT area_name) AS total_unique_area
FROM transactions
WHERE LOWER(TRIM(trans_group)) = 'sales';
-------------------------------------------------------------------------
CREATE VIEW line_chart AS
SELECT 
year,
ROUND(SUM(actual_worth_capped)::NUMERIC,2) AS net_transaction_value
FROM transactions
WHERE LOWER (TRIM(trans_group))='sales' AND year BETWEEN 1998 AND 2025
GROUP BY year
ORDER BY year
--------------------------------------------------------------------------
CREATE VIEW property_type_summary AS
SELECT 
    property_type,
    ROUND(SUM(actual_worth_capped)::NUMERIC, 2) AS net_transaction_value,
    COUNT(*) AS txn_count
FROM transactions 
WHERE LOWER(TRIM(trans_group)) = 'sales' 
  AND year BETWEEN 1998 AND 2025
GROUP BY property_type;
--------------------------------------------------------------------------
SELECT 
    area_name,
    COUNT(*) AS txn_count
FROM transactions
WHERE LOWER(TRIM(trans_group)) = 'sales'
  AND year BETWEEN 1998 AND 2025
GROUP BY area_name
ORDER BY txn_count ASC
LIMIT 20;

SELECT COUNT(DISTINCT area_name) AS total_areas
FROM transactions
WHERE LOWER(TRIM(trans_group)) = 'sales'
  AND year BETWEEN 2018 AND 2020
GROUP BY area_name
HAVING COUNT(*) < 30;
--------------------------------------------------------------------------
WITH window_early AS (
    SELECT 
        area_name,
        property_type,
        COUNT(*) AS txn_count_early,
        ROUND(AVG(actual_worth_capped)::NUMERIC, 2) AS avg_value_early
    FROM transactions
    WHERE LOWER(TRIM(trans_group)) = 'sales'
      AND property_type IN ('Unit', 'Villa', 'Land')
      AND year BETWEEN 2018 AND 2020
    GROUP BY area_name, property_type
    HAVING COUNT(*) >= 5
),
window_recent AS (
    SELECT 
        area_name,
        property_type,
        COUNT(*) AS txn_count_recent,
        ROUND(AVG(actual_worth_capped)::NUMERIC, 2) AS avg_value_recent
    FROM transactions
    WHERE LOWER(TRIM(trans_group)) = 'sales'
      AND property_type IN ('Unit', 'Villa', 'Land')
      AND year BETWEEN 2023 AND 2025
    GROUP BY area_name, property_type
    HAVING COUNT(*) >= 5
)
SELECT 
    e.area_name,
    e.property_type,
    e.txn_count_early,
    e.avg_value_early,
    r.txn_count_recent,
    r.avg_value_recent,
    ROUND(
        ((r.avg_value_recent - e.avg_value_early) / e.avg_value_early) * 100, 2
    ) AS growth_pct
FROM window_early e
INNER JOIN window_recent r 
    ON e.area_name = r.area_name 
    AND e.property_type = r.property_type
ORDER BY e.property_type, growth_pct DESC;
----------------------------------------------------------------------------------
SELECT DISTINCT area_name
FROM transactions
WHERE LOWER(TRIM(trans_group)) = 'sales'
  AND property_type IN ('Unit', 'Villa', 'Land')
  AND year BETWEEN 2018 AND 2025
ORDER BY area_name;
----------------------------------------------------------------------------------
SELECT DISTINCT nearest_mall AS place_name, 'mall' AS place_type
FROM transactions
WHERE LOWER(TRIM(trans_group)) = 'sales'
  AND nearest_mall <> 'Unknown'

UNION

SELECT DISTINCT nearest_metro AS place_name, 'metro' AS place_type
FROM transactions
WHERE LOWER(TRIM(trans_group)) = 'sales'
  AND nearest_metro <> 'Unknown'

ORDER BY place_type, place_name;
--------------------------------------------------------------------------------------
SELECT DISTINCT nearest_metro
FROM transactions
WHERE LOWER(TRIM(trans_group)) = 'sales'
  AND nearest_metro <> 'Unknown'
  AND nearest_metro NOT ILIKE '%metro station%'
ORDER BY nearest_metro;
-------------------------------------------------------------------------------
SELECT DISTINCT 
    CASE 
        WHEN nearest_metro = 'Jumeirah Beach Resdency' THEN 'Jumeirah Beach Residency'
        ELSE nearest_metro
    END AS place_name,
    'metro' AS place_type
FROM transactions
WHERE LOWER(TRIM(trans_group)) = 'sales'
  AND nearest_metro <> 'Unknown'
  AND nearest_metro ILIKE '%metro station%'

UNION

SELECT DISTINCT nearest_mall AS place_name, 'mall' AS place_type
FROM transactions
WHERE LOWER(TRIM(trans_group)) = 'sales'
  AND nearest_mall <> 'Unknown'

ORDER BY place_type, place_name;
----------------------------------------------------------------------------------
CREATE VIEW area_property_growth AS
WITH window_early AS (
    SELECT 
        area_name,
        property_type,
        COUNT(*) AS txn_count_early,
        ROUND(AVG(actual_worth_capped)::NUMERIC, 2) AS avg_value_early
    FROM transactions
    WHERE LOWER(TRIM(trans_group)) = 'sales'
      AND property_type IN ('Unit', 'Villa', 'Land')
      AND year BETWEEN 2018 AND 2020
    GROUP BY area_name, property_type
    HAVING COUNT(*) >= 5
),
window_recent AS (
    SELECT 
        area_name,
        property_type,
        COUNT(*) AS txn_count_recent,
        ROUND(AVG(actual_worth_capped)::NUMERIC, 2) AS avg_value_recent
    FROM transactions
    WHERE LOWER(TRIM(trans_group)) = 'sales'
      AND property_type IN ('Unit', 'Villa', 'Land')
      AND year BETWEEN 2023 AND 2025
    GROUP BY area_name, property_type
    HAVING COUNT(*) >= 5
)
SELECT 
    e.area_name,
    e.property_type,
    e.txn_count_early,
    e.avg_value_early,
    r.txn_count_recent,
    r.avg_value_recent,
    ROUND(
        ((r.avg_value_recent - e.avg_value_early) / e.avg_value_early) * 100, 2
    ) AS growth_pct
FROM window_early e
INNER JOIN window_recent r 
    ON e.area_name = r.area_name 
	----------------------------------------------------------------------
SELECT 
year,
count(*)AS transaction_count
FROM transactions
WHERE LOWER(TRIM(trans_group)) = 'sales' AND year BETWEEN 1998 AND 2025
GROUP BY year

SELECT * FROM transactions
LIMIT(10)
---------------------------------------------------------------------------
SELECT
    area_name,
    year,
    SUM(actual_worth_capped) AS total_value,
    AVG(actual_worth_capped) AS avg_value,
    COUNT(*) AS txn_count
FROM transactions
WHERE trans_group = 'Sales'
    AND year BETWEEN 2000 AND 2025
GROUP BY area_name, year
ORDER BY area_name, year;

SELECT * FROM transactions
LIMIT 10
---------------------------------------------------------------------------------
SELECT COUNT(*) FROM area_cluster_assignments; 
SELECT * FROM cluster_profile_summary; 
SELECT * FROM area_cluster_assignments WHERE area_name ILIKE '%marsa%';
SELECT * FROM cluster_profile_summary ORDER BY cluster;
SELECT * FROM cluster_radar_scores ORDER BY cluster, "Metric";