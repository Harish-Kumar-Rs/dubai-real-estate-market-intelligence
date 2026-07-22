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