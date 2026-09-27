-- =====================================================================
-- Commission Engine: Execution and Validation
-- =====================================================================

-- Run the engine for January and February 2026
BEGIN
    pkg_commission_engine.calculate_period('2026-01');
    pkg_commission_engine.calculate_period('2026-02');
END;
/

-- Commission report
SELECT sl.seller_name,
       cr.period_month,
       cr.product_category,
       cr.total_sales,
       cr.commission_rate * 100 AS rate_pct,
       cr.commission_amount
  FROM commission_results cr
  JOIN sellers sl ON sl.seller_id = cr.seller_id
 ORDER BY cr.period_month, sl.seller_name, cr.product_category;