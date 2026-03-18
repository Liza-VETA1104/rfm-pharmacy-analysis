-- Прогноз риска оттока среди ЦЕННЫХ клиентов
-- Фокус: VIP, Champions, Loyal, Recent Loyal


WITH snapshot AS (
    SELECT MAX(Datetime) + INTERVAL '1 day' AS snap_date
    FROM bonuscheques
),
rfm_base AS (
    SELECT 
        Card AS customer_id,
        EXTRACT(DAY FROM (snap_date - MAX(Datetime)))::INTEGER AS recency_days,
        COUNT(*) AS frequency,
        ROUND(SUM(summ_with_disc), 2) AS monetary,
        MIN(Datetime) AS first_purchase,
        MAX(Datetime) AS last_purchase
    FROM bonuscheques
    CROSS JOIN snapshot
    GROUP BY Card, snap_date
),
rfm_scored AS (
    SELECT 
        *,
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
        *,
        CASE 
            WHEN monetary >= 20000 THEN 'Wholesale / VIP'
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
),
-- ФИЛЬТР: только ценные сегменты!
valuable_customers AS (
    SELECT *
    FROM final_rfm
    WHERE segment IN (
        'Wholesale / VIP',
        'Champions',
        'Recent Loyal',
        'Loyal'
       )
),

-- РАСЧЁТ РИСКА ОТТОКА
churn_risk AS (
    SELECT 
        customer_id,
        segment,
        recency_days,
        frequency,
        monetary,
        first_purchase,
        last_purchase,
  -- Типичный цикл покупок (в днях)
        CASE 
            WHEN frequency >= 2 THEN 
                ROUND((EXTRACT(EPOCH FROM (last_purchase - first_purchase)) / 86400 / (frequency - 1))::NUMERIC, 0)
            ELSE NULL 
        END AS avg_purchase_cycle_days,
        
        -- Уровень риска оттока
        CASE 
            WHEN frequency >= 2 AND recency_days > (
                (EXTRACT(EPOCH FROM (last_purchase - first_purchase)) / 86400 / (frequency - 1)) * 2
            ) THEN 'High Risk'
        END AS churn_risk_level
        
    FROM valuable_customers
)
-- АГРЕГАЦИЯ ПО СЕГМЕНТАМ
SELECT 
    segment,
    COUNT(*) FILTER (WHERE churn_risk_level = 'High Risk') AS high_risk,
    ROUND(100.0 * COUNT(*) FILTER (WHERE churn_risk_level = 'High Risk') / COUNT(*), 1) AS pct_at_risk,
    ROUND(SUM(monetary) FILTER (WHERE churn_risk_level ='High Risk')::NUMERIC, 0) AS revenue_at_risk
FROM churn_risk
GROUP BY segment
ORDER BY revenue_at_risk DESC;
