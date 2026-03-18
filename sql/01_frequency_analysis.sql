-- Анализ распределения Frequency для RFM-сегментации

-- Сводная статистика и процентили
-- Цель: понять "разброс" данных
WITH customer_freq AS (
    SELECT 
        Card,
        COUNT(*) AS frequency
    FROM bonuscheques
    GROUP BY Card
)
SELECT 
    COUNT(*) AS total_customers,
    MIN(frequency) AS min_freq,
    MAX(frequency) AS max_freq,
    ROUND(AVG(frequency), 1) AS avg_freq,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY frequency) AS median_freq,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY frequency) AS p75_freq,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY frequency) AS p90_freq,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY frequency) AS p95_freq
FROM customer_freq;

-- Полное распределение 
-- Цель: на основе результатов определить пороги
SELECT 
    frequency AS num_purchases,
    COUNT(*) AS customers_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM (
    SELECT 
        Card AS customer_id,
        COUNT(*) AS frequency
    FROM bonuscheques
    GROUP BY Card
) AS freq_table
GROUP BY frequency
ORDER BY frequency

  
