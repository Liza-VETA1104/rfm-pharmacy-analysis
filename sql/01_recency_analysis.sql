-- Анализ распределения Recency для RFM-сегментации

-- Сводная статистика и процентили
-- Цель: понять "разброс" данных по давности покупок

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
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY recency_days) AS p25_recency,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY recency_days) AS median_recency,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY recency_days) AS p75_recency,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY recency_days) AS p90_recency,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY recency_days) AS p95_recency
FROM customer_recency
