-- Статистика по RFM-сегментам

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
        CASE 
            WHEN recency_days <= 14 THEN 5
            WHEN recency_days <= 30 THEN 4
            WHEN recency_days <= 60 THEN 3
            WHEN recency_days <= 180 THEN 2
            ELSE 1
        END AS r_score,
        CASE 
            WHEN frequency = 1 THEN 1
            WHEN frequency BETWEEN 2 AND 3 THEN 2
            WHEN frequency BETWEEN 4 AND 5 THEN 3
            WHEN frequency BETWEEN 6 AND 10 THEN 4
            ELSE 5
        END AS f_score,
        CASE 
            WHEN monetary < 500 THEN 1
            WHEN monetary < 1500 THEN 2
            WHEN monetary < 3500 THEN 3
            WHEN monetary < 7500 THEN 4
            ELSE 5
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
                                                      
            -- 2. RFM-сегменты
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 4 AND f_score >= 3 THEN 'Recent Loyal'
            WHEN r_score >= 3 AND f_score >= 4 THEN 'Loyal'
            WHEN r_score >= 4 THEN 'Recent'
            WHEN f_score >= 4 THEN 'High Frequency'
            WHEN r_score = 1 THEN 'Lost'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'At Risk'
            ELSE 'Mid / Other'
        END AS segment
        
    FROM rfm_scored
)

-- СТАТИСТИКА ПО СЕГМЕНТАМ
SELECT 
    segment,
    COUNT(*) AS customers_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_total,
    ROUND(AVG(monetary), 0) AS avg_monetary,
    ROUND(SUM(monetary), 0) AS total_revenue,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_revenue,
    ROUND(AVG(frequency), 1) AS avg_frequency,
    ROUND(AVG(recency_days), 0) AS avg_recency
FROM final_rfm
GROUP BY segment
ORDER BY pct_of_total DESC
