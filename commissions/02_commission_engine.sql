-- =====================================================================
-- Commission Engine: PL/SQL Package
-- Author: Eduardo Lamarca
-- Description: Calculates monthly tiered commissions per seller and
--              product category. Recalculation is idempotent: running
--              the same period twice replaces previous results.
-- Business rules:
--   1. Only PAID sales generate commission
--   2. Inactive sellers do not receive commission
--   3. Rate depends on monthly volume per category (tiered rules)
-- =====================================================================

CREATE OR REPLACE PACKAGE pkg_commission_engine AS

    FUNCTION get_commission_rate (
        p_category IN VARCHAR2,
        p_total    IN NUMBER
    ) RETURN NUMBER;

    PROCEDURE calculate_period (
        p_period IN VARCHAR2  -- format: YYYY-MM
    );

END pkg_commission_engine;
/

CREATE OR REPLACE PACKAGE BODY pkg_commission_engine AS

    -- -----------------------------------------------------------------
    -- Returns the commission rate for a category and monthly total
    -- -----------------------------------------------------------------
    FUNCTION get_commission_rate (
        p_category IN VARCHAR2,
        p_total    IN NUMBER
    ) RETURN NUMBER
    IS
        v_rate commission_rules.commission_rate%TYPE;
    BEGIN
        SELECT commission_rate
          INTO v_rate
          FROM commission_rules
         WHERE product_category = p_category
           AND p_total >= min_monthly_sales
           AND (max_monthly_sales IS NULL OR p_total < max_monthly_sales);

        RETURN v_rate;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002,
                'No commission rule found for category ' || p_category ||
                ' and amount ' || p_total);
        WHEN TOO_MANY_ROWS THEN
            RAISE_APPLICATION_ERROR(-20003,
                'Overlapping commission rules for category ' || p_category);
    END get_commission_rate;

    -- -----------------------------------------------------------------
    -- Calculates all commissions for a given month
    -- -----------------------------------------------------------------
    PROCEDURE calculate_period (
        p_period IN VARCHAR2
    )
    IS
        v_start_date DATE;
        v_end_date   DATE;
        v_rate       NUMBER;
        v_rows       PLS_INTEGER := 0;
    BEGIN
        -- Validate period format (YYYY-MM, month 01-12)
        IF NOT REGEXP_LIKE(p_period, '^\d{4}-(0[1-9]|1[0-2])$') THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Invalid period "' || p_period || '". Expected format: YYYY-MM');
        END IF;

        v_start_date := TO_DATE(p_period || '-01', 'YYYY-MM-DD');
        v_end_date   := ADD_MONTHS(v_start_date, 1);

        -- Idempotency: remove previous results for this period
        DELETE FROM commission_results
         WHERE period_month = p_period;

        -- Aggregate eligible sales per seller and category
        FOR r IN (
            SELECT s.seller_id,
                   s.product_category,
                   SUM(s.amount) AS total_sales
              FROM sales s
              JOIN sellers sl ON sl.seller_id = s.seller_id
             WHERE s.status    = 'PAID'
               AND sl.active   = 'Y'
               AND s.sale_date >= v_start_date
               AND s.sale_date <  v_end_date
             GROUP BY s.seller_id, s.product_category
        ) LOOP
            v_rate := get_commission_rate(r.product_category, r.total_sales);

            INSERT INTO commission_results (
                seller_id, period_month, product_category,
                total_sales, commission_rate, commission_amount
            ) VALUES (
                r.seller_id, p_period, r.product_category,
                r.total_sales, v_rate, ROUND(r.total_sales * v_rate, 2)
            );

            v_rows := v_rows + 1;
        END LOOP;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Period ' || p_period || ': ' ||
                             v_rows || ' commission records calculated.');

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END calculate_period;

END pkg_commission_engine;
/