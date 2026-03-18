-- Анализ распределения Recency для RFM-сегментации

-- Сводная статистика и процентили


WITH snapshot AS (
    SELECT MAX(Datetime) + INTERVAL '1 day' AS snap_date
    FROM bonuscheques
),
customer_recency AS (
    SELECT 
        Card,
        EXTRACT(DAY FROM (snap_date - MAX(Datetime)))::INTEGER AS recency_days
    FROM bonuscheques
    CROSS JOIN snapshot
    GROUP BY Card, snap_date
)
SELECT 
    COUNT(*) AS total_customers,
    MIN(recency_days) AS min_recency,
    MAX(recency_days) AS max_recency,
    ROUND(AVG(recency_days), 1) AS avg_recency,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY recency_days) AS median_recency,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY recency_days) AS p75_recency,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY recency_days) AS p90_recency,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY recency_days) AS p95_recency
FROM customer_recency

--Полное распределение (сгруппированное по неделям)

WITH snapshot AS (
    SELECT MAX(Datetime) + INTERVAL '1 day' AS snap_date
    FROM bonuscheques
),
customer_recency AS (
    SELECT 
        Card AS customer_id,
        EXTRACT(DAY FROM (snap_date - MAX(Datetime)))::INTEGER AS recency_days
    FROM bonuscheques
    CROSS JOIN snapshot
    GROUP BY Card, snap_date
)
SELECT 
    FLOOR(recency_days / 7) * 7 AS week_bucket,  -- Группировка по неделям
    COUNT(*) AS customers_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_total,
    MIN(recency_days) AS min_days,
    MAX(recency_days) AS max_days
FROM customer_recency
GROUP BY FLOOR(recency_days / 7) * 7
ORDER BY week_bucket


-- Присвоение оценок Recency (R-score от 1 до 5)
-- МЕНЬШЕ дней = ЛУЧШЕ = ВЫШЕ оценка

WITH snapshot AS (
    SELECT MAX(Datetime) + INTERVAL '1 day' AS snap_date
    FROM bonuscheques
),
customer_recency AS (
    SELECT 
        Card AS customer_id,
        EXTRACT(DAY FROM (snap_date - MAX(Datetime)))::INTEGER AS recency_days
    FROM bonuscheques
    CROSS JOIN snapshot
    GROUP BY Card, snap_date
)

SELECT 
    customer_id,
    recency_days, 
    CASE 
        WHEN recency_days <= 14 THEN 5        -- Очень свежие (до 2х недель)
        WHEN recency_days <= 30 THEN 4        -- Свежие (до 1 месяца)
        WHEN recency_days <= 60 THEN 3       -- Средний риск (1-2 месяца)
        WHEN recency_days <= 180 THEN 2       -- Высокий риск (2-6 месяцев)
        ELSE 1                                 -- Потерянные (6+ месяцев)
    END AS r_score,
    
    CASE 
        WHEN recency_days <= 14 THEN 'Very Recent'
        WHEN recency_days <= 30 THEN 'Recent'
        WHEN recency_days <= 60 THEN 'Medium Risk'
        WHEN recency_days <= 180 THEN 'High Risk'
        ELSE 'Lost'
    END AS recency_segment

FROM customer_recency
ORDER BY recency_days
