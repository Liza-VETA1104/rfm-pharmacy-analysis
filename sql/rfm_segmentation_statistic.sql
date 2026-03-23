--Расчет статистик на основе final_rfm 



-- СРЕДНИЙ ЧЕК
SELECT 
    ROUND(AVG(avg_check), 0) AS avg_check
FROM final_rfm

--LTV 
SELECT 
    ROUND(AVG(monetary), 0) AS ltv
FROM final_rfm
