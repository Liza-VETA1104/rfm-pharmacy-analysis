-- Анализ распределения Monetary для RFM-сегментации

-- Сводная статистика и процентили
-- Цель: понять "разброс" данных по сумме покупок

WITH customer_monetary AS (
    SELECT 
        Card,
        ROUND(SUM(summ_with_disc), 2) AS monetary
    FROM bonuscheques
    GROUP BY Card
)
SELECT 
    COUNT(*) AS total_customers,
    MIN(monetary) AS min_monetary,
    MAX(monetary) AS max_monetary,
    ROUND(AVG(monetary), 2) AS avg_monetary,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY monetary) AS median_monetary,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY monetary) AS p75_monetary,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY monetary) AS p90_monetary,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY monetary) AS p95_monetary
FROM customer_monetary

--Полное распределение (сгруппированное по корзинам)
WITH customer_monetary AS (
    SELECT 
        Card AS customer_id,
        ROUND(SUM(summ_with_disc), 2) AS monetary
    FROM bonuscheques
    GROUP BY Card
)
SELECT 
    FLOOR(monetary / 500) * 500 AS monetary_bucket,  -- Группировка по 500 ₽
    COUNT(*) AS customers_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_total,
    ROUND(MIN(monetary), 0) AS min_monetary,
    ROUND(MAX(monetary), 0) AS max_monetary,
    ROUND(AVG(monetary), 0) AS avg_monetary_in_bucket
FROM customer_monetary
GROUP BY FLOOR(monetary / 500) * 500
ORDER BY monetary_bucket


WITH customer_monetary AS (
    SELECT 
        Card AS customer_id,
        ROUND(SUM(summ_with_disc), 2) AS monetary
    FROM bonuscheques
    GROUP BY Card
)

SELECT 
    customer_id,
    monetary,
    
    -- 🔥 ОЦЕНКИ НА ОСНОВЕ РЕАЛЬНЫХ ДАННЫХ
    CASE 
        WHEN monetary < 500 THEN 1           -- Низкая ценность
        WHEN monetary < 1500 THEN 2          -- Средняя (вокруг медианы 1,586)
        WHEN monetary < 3500 THEN 3          -- Хорошая (вокруг среднего 3,416)
        WHEN monetary < 7500 THEN 4          -- Высокая (до P90=7,899)
        WHEN monetary < 20000 THEN 5         -- Очень высокая (до P95=11,859)
        ELSE 5                                -- VIP (20,000+, единичные)
    END AS m_score,
    
    CASE 
        WHEN monetary < 500 THEN 'Low Value'
        WHEN monetary < 1500 THEN 'Medium Value'
        WHEN monetary < 3500 THEN 'Good Value'
        WHEN monetary < 7500 THEN 'High Value'
        WHEN monetary < 20000 THEN 'Very High Value'
        ELSE 'VIP'
    END AS monetary_segment

FROM customer_monetary
ORDER BY monetary

  
-- Присвоение оценок Monetary (M-score от 1 до 5)

WITH customer_monetary AS (
    SELECT 
        Card AS customer_id,
        ROUND(SUM(summ_with_disc), 2) AS monetary
    FROM bonuscheques
    GROUP BY Card
)
SELECT 
    customer_id,
    monetary,
    CASE 
        WHEN monetary < 500 THEN 1           -- Низкая ценность
        WHEN monetary < 1500 THEN 2          -- Средняя (вокруг медианы 1,586)
        WHEN monetary < 3500 THEN 3          -- Хорошая (вокруг среднего 3,416)
        WHEN monetary < 7500 THEN 4          -- Высокая (до P90=7,899)
        WHEN monetary < 20000 THEN 5         -- Очень высокая (до P95=11,859)
        ELSE 5                                -- VIP (20,000+, единичные)
    END AS m_score,
    CASE 
        WHEN monetary < 500 THEN 'Low Value'
        WHEN monetary < 1500 THEN 'Medium Value'
        WHEN monetary < 3500 THEN 'Good Value'
        WHEN monetary < 7500 THEN 'High Value'
        WHEN monetary < 20000 THEN 'Very High Value'
        ELSE 'VIP'
    END AS monetary_segment
FROM customer_monetary
ORDER BY monetary
