-- Финальная RFM-сегментация клиентов
-- С выделением Wholesale / VIP (monetary >= 20,000)


WITH snapshot AS (
    SELECT MAX(Datetime) + INTERVAL '1 day' AS snap_date
    FROM bonuscheques
),

rfm_base AS (
    SELECT 
        Card AS customer_id,
        EXTRACT(DAY FROM (snap_date - MAX(Datetime)))::INTEGER AS recency_days,
        COUNT(*) AS frequency,
        ROUND(SUM(summ_with_disc), 2) AS monetary
    FROM bonuscheques
    CROSS JOIN snapshot
    GROUP BY Card, snap_date
),

rfm_scored AS (
    SELECT 
        customer_id,
        recency_days,
        frequency,
        monetary,
        
        -- R-Score 
        CASE 
            WHEN recency_days <= 14 THEN 5        -- Очень свежие (до 2 недель)
            WHEN recency_days <= 30 THEN 4        -- Свежие (до 1 месяца)
            WHEN recency_days <= 60 THEN 3        -- Средний риск (1-2 месяца)
            WHEN recency_days <= 180 THEN 2       -- Высокий риск (2-6 месяцев)
            ELSE 1                                 -- Потерянные (6+ месяцев)
        END AS r_score,
        
        -- F-Score 
        CASE 
            WHEN frequency = 1 THEN 1              -- 40.5% базы
            WHEN frequency BETWEEN 2 AND 3 THEN 2  -- 27.2% базы
            WHEN frequency BETWEEN 4 AND 5 THEN 3  -- 10.4% базы
            WHEN frequency BETWEEN 6 AND 10 THEN 4 -- 6.1% базы
            ELSE 5                                  -- 11+ покупок
        END AS f_score,
        
        -- M-Score 
        CASE 
            WHEN monetary < 500 THEN 1    -- Низкая ценность           
            WHEN monetary < 1500 THEN 2   -- Средняя (вокруг медианы 1,586)
            WHEN monetary < 3500 THEN 3   -- Хорошая (вокруг среднего 3,416)
            WHEN monetary < 7500 THEN 4   -- Высокая (до P90=7,899)
            ELSE 5                        -- 7,500+ ₽
        END AS m_score
        
    FROM rfm_base
),

final_rfm AS (
    SELECT 
        customer_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        CONCAT(r_score, '-', f_score, '-', m_score) AS rfm_score,
        
        
        CASE 
            -- 1. Особый сегмент
            WHEN monetary >= 20000 AND monetary/ frequency <= 7500 THEN 'VIP'
            WHEN monetary >= 20000 THEN 'Wholesale/Random' --следует посмотреть, что именно было куплено (мелкий опт, редкие единичные дорогостоящие покупки)
            
            -- 2. RFM-сегменты
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 4 AND f_score >= 3 THEN 'Recent Loyal'
            WHEN r_score >= 3 AND f_score >= 4 THEN 'Loyal'
            WHEN r_score >= 4 THEN 'Recent'
            WHEN f_score >= 4 THEN 'High Frequency'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'At Risk'
            WHEN r_score = 1 THEN 'Lost'
            ELSE 'Mid / Other'
        END AS segment
        
    FROM rfm_scored
)

SELECT * FROM final_rfm
ORDER BY monetary DESC, frequency DESC;
