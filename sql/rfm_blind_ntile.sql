WITH snapshot AS (
    SELECT 
        MAX(Datetime) + INTERVAL '1 day' AS snap_date
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
        *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,   -- 5 = самые свежие
        NTILE(5) OVER (ORDER BY frequency ASC)     AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score
    FROM rfm_base
), 

final_rfm AS (    
    SELECT 
        customer_id,
        recency_days,
        frequency,
        monetary,
        CONCAT(r_score, '-', f_score, '-', m_score) AS rfm_score,
        CASE 
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 4 AND f_score >= 3                  THEN 'Recent Loyal'
            WHEN r_score >= 3 AND f_score >= 4                  THEN 'Loyal'
            WHEN r_score >= 4                                   THEN 'Recent'
            WHEN f_score >= 4                                   THEN 'High Frequency'
            WHEN r_score <= 2 AND f_score <= 2                  THEN 'At Risk'
            WHEN r_score <= 1                                   THEN 'Lost'
            ELSE 'Mid / Other'
        END AS segment
    FROM rfm_scored
    ORDER BY monetary DESC, frequency DESC
),

segment_pct AS (
    SELECT 
        segment, 
        COUNT(*) AS cnt, 
        ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
    FROM final_rfm
    GROUP BY segment
    ORDER BY cnt DESC
),

-- Аналитика порогов: статистика по каждому скору (R, F, M)
score_statistics AS (
    SELECT 
        'Recency' AS metric,
        r_score AS score,
        MIN(recency_days) AS min_val,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY recency_days) AS median_val,
        ROUND(AVG(recency_days)::NUMERIC, 1) AS avg_val,
        MAX(recency_days) AS max_val,
        COUNT(*) AS customers_in_score
    FROM rfm_scored
    GROUP BY r_score
    UNION ALL
    SELECT 
        'Frequency' AS metric,
        f_score AS score,
        MIN(frequency)::NUMERIC,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY frequency)::NUMERIC,
        ROUND(AVG(frequency)::NUMERIC, 1),
        MAX(frequency)::NUMERIC,
        COUNT(*)
    FROM rfm_scored
    GROUP BY f_score
    UNION ALL
    SELECT 
        'Monetary' AS metric,
        m_score AS score,
        MIN(monetary)::NUMERIC,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY monetary)::NUMERIC,
        ROUND(AVG(monetary)::NUMERIC, 2),
        MAX(monetary)::NUMERIC,
        COUNT(*)
    FROM rfm_scored
    GROUP BY m_score
)
-- Финальный вывод
SELECT * FROM score_statistics
ORDER BY metric, score DESC;
