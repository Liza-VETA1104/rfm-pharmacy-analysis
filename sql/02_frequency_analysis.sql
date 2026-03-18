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

    
-- Присвоение оценок Frequency (F-score от 1 до 5)
WITH customer_freq AS (
    SELECT 
        Card AS customer_id,
        COUNT(*) AS frequency
    FROM bonuscheques
    GROUP BY Card
)
SELECT 
    customer_id,
    frequency,
    CASE 
        WHEN frequency = 1 THEN 1              -- 40.5% базы (3,800 клиентов)
        WHEN frequency BETWEEN 2 AND 3 THEN 2  -- 27.2% базы
        WHEN frequency BETWEEN 4 AND 5 THEN 3  -- 10.4% базы (до P75)
        WHEN frequency BETWEEN 6 AND 10 THEN 4 -- 6.1% базы (до P90)
        WHEN frequency BETWEEN 11 AND 35 THEN 5-- 2.8% базы (топ-10%)
        WHEN frequency > 35 THEN 5             -- 0.1% (VIP, опт)
    END AS f_score,
    CASE 
        WHEN frequency = 1 THEN 'One-time'
        WHEN frequency BETWEEN 2 AND 3 THEN 'Low Loyalty'
        WHEN frequency BETWEEN 4 AND 5 THEN 'Medium Loyalty'
        WHEN frequency BETWEEN 6 AND 10 THEN 'High Loyalty'
        WHEN frequency >= 11 THEN 'Super Loyal'
    END AS frequency_segment
FROM customer_freq
ORDER BY frequency;

  
