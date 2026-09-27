-- =====================================================================
-- Commission Engine: Schema and Sample Data
-- Author: Eduardo Lamarca
-- Description: Tables for a tiered sales commission model, where the
--              commission rate depends on each seller's monthly sales
--              volume per product category.
-- =====================================================================

-- Drop tables if they already exist (children first, due to FKs)
DROP TABLE IF EXISTS commission_results;
DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS commission_rules;
DROP TABLE IF EXISTS sellers;

-- ---------------------------------------------------------------------
-- Sellers
-- ---------------------------------------------------------------------
CREATE TABLE sellers (
    seller_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_name  VARCHAR2(100) NOT NULL,
    region       VARCHAR2(20)  NOT NULL,
    hire_date    DATE          NOT NULL,
    active       CHAR(1) DEFAULT 'Y' NOT NULL
                 CONSTRAINT chk_seller_active CHECK (active IN ('Y', 'N'))
);

-- ---------------------------------------------------------------------
-- Commission rules (tiered by monthly sales volume per category)
-- Rule applies when: min_monthly_sales <= total < max_monthly_sales
-- A NULL max_monthly_sales means "no upper limit"
-- ---------------------------------------------------------------------
CREATE TABLE commission_rules (
    rule_id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_category   VARCHAR2(30) NOT NULL,
    min_monthly_sales  NUMBER(12,2) NOT NULL,
    max_monthly_sales  NUMBER(12,2),
    commission_rate    NUMBER(5,4)  NOT NULL
);

-- ---------------------------------------------------------------------
-- Sales transactions
-- Only PAID sales generate commission
-- ---------------------------------------------------------------------
CREATE TABLE sales (
    sale_id           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id         NUMBER       NOT NULL REFERENCES sellers(seller_id),
    sale_date         DATE         NOT NULL,
    product_category  VARCHAR2(30) NOT NULL,
    amount            NUMBER(12,2) NOT NULL,
    status            VARCHAR2(10) NOT NULL
                      CONSTRAINT chk_sale_status
                      CHECK (status IN ('PAID', 'PENDING', 'CANCELLED'))
);

-- ---------------------------------------------------------------------
-- Commission results (output of the engine)
-- ---------------------------------------------------------------------
CREATE TABLE commission_results (
    result_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id          NUMBER       NOT NULL REFERENCES sellers(seller_id),
    period_month       VARCHAR2(7)  NOT NULL,  -- format: YYYY-MM
    product_category   VARCHAR2(30) NOT NULL,
    total_sales        NUMBER(12,2) NOT NULL,
    commission_rate    NUMBER(5,4)  NOT NULL,
    commission_amount  NUMBER(12,2) NOT NULL,
    calculated_at      DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT uq_commission UNIQUE (seller_id, period_month, product_category)
);

-- =====================================================================
-- Sample data
-- =====================================================================

INSERT INTO sellers (seller_name, region, hire_date, active) VALUES ('Ana Souza',    'SOUTH', DATE '2019-03-01', 'Y');
INSERT INTO sellers (seller_name, region, hire_date, active) VALUES ('Bruno Lima',   'NORTH', DATE '2020-07-15', 'Y');
INSERT INTO sellers (seller_name, region, hire_date, active) VALUES ('Carla Mendes', 'EAST',  DATE '2018-11-20', 'Y');
INSERT INTO sellers (seller_name, region, hire_date, active) VALUES ('Diego Rocha',  'WEST',  DATE '2021-02-10', 'N');

-- Coffee: 3 tiers
INSERT INTO commission_rules (product_category, min_monthly_sales, max_monthly_sales, commission_rate) VALUES ('COFFEE', 0,     10000, 0.0200);
INSERT INTO commission_rules (product_category, min_monthly_sales, max_monthly_sales, commission_rate) VALUES ('COFFEE', 10000, 30000, 0.0300);
INSERT INTO commission_rules (product_category, min_monthly_sales, max_monthly_sales, commission_rate) VALUES ('COFFEE', 30000, NULL,  0.0400);
-- Fertilizers: 2 tiers
INSERT INTO commission_rules (product_category, min_monthly_sales, max_monthly_sales, commission_rate) VALUES ('FERTILIZERS', 0,     20000, 0.0150);
INSERT INTO commission_rules (product_category, min_monthly_sales, max_monthly_sales, commission_rate) VALUES ('FERTILIZERS', 20000, NULL,  0.0250);
-- Equipment: flat rate
INSERT INTO commission_rules (product_category, min_monthly_sales, max_monthly_sales, commission_rate) VALUES ('EQUIPMENT', 0, NULL, 0.0500);

-- January 2026
INSERT INTO sales (seller_id, sale_date, product_category, amount, status) VALUES (1, DATE '2026-01-05', 'COFFEE',      12000, 'PAID');
INSERT INTO sales (seller_id, sale_date, product_category, amount, status) VALUES (1, DATE '2026-01-18', 'COFFEE',       8500, 'PAID');
INSERT INTO sales (seller_id, sale_date, product_category, amount, status) VALUES (1, DATE '2026-01-22', 'FERTILIZERS', 15000, 'PAID');
INSERT INTO sales (seller_id, sale_date, product_category, amount, status) VALUES (1, DATE '2026-01-25', 'EQUIPMENT',    4000, 'CANCELLED');
INSERT INTO sales (seller_id, sale_date, product_category, amount, status) VALUES (2, DATE '2026-01-10', 'COFFEE',       6000, 'PAID');
INSERT INTO sales (seller_id, sale_date, product_category, amount, status) VALUES (2, DATE '2026-01-14', 'EQUIPMENT',    9000, 'PAID');
INSERT INTO sales (seller_id, sale_date, product_category, amount, status) VALUES (2, DATE '2026-01-28', 'FERTILIZERS', 22000, 'PENDING');
INSERT INTO sales (seller_id, sale_date, product_category, amount, status) VALUES (3, DATE '2026-01-08', 'COFFEE',      35000, 'PAID');
INSERT INTO sales (seller_id, sale_date, product_category, amount, status) VALUES (3, DATE '2026-01-20', 'FERTILIZERS', 21000, 'PAID');
INSERT INTO sales (seller_id, sale_date, product_category, amount, status) VALUES (4, DATE '2026-01-12', 'COFFEE',       5000, 'PAID');

-- February 2026
INSERT INTO sales (seller_id, sale_date, product_category, amount, status) VALUES (1, DATE '2026-02-03', 'COFFEE',       7000, 'PAID');
INSERT INTO sales (seller_id, sale_date, product_category, amount, status) VALUES (2, DATE '2026-02-09', 'FERTILIZERS', 25000, 'PAID');
INSERT INTO sales (seller_id, sale_date, product_category, amount, status) VALUES (3, DATE '2026-02-15', 'EQUIPMENT',   12000, 'PAID');

COMMIT;