-- =====================================================================
-- ALY6600 Lab Assignment 8
-- CTE queries
-- Darpan Radadiya
-- Prof. Nayem Rahman
-- Dataset: Sakila subset in BigQuery, aly6600-lab-1.aly6600_lab8
-- =====================================================================


-- ============ TASK 1: SINGLE CTE ============

-- Business question: which customers spend more than the average
-- customer? The CTE computes one total per customer. The outer query
-- compares each total against the average of those totals.
--
-- The grain of the average is the point of this task. It must be the
-- average of customer totals, not the average of payment rows.
-- Those are $112.53 and $4.20, which answer different questions.
WITH customer_spend AS (
    SELECT
        customer_id,
        COUNT(*)      AS payment_count,
        SUM(amount)   AS total_spend
    FROM `aly6600-lab-1.aly6600_lab8.payment`
    GROUP BY customer_id
)
SELECT
    cs.customer_id,
    c.first_name,
    c.last_name,
    cs.payment_count,
    ROUND(cs.total_spend, 2) AS total_spend,
    ROUND((SELECT AVG(total_spend) FROM customer_spend), 2)
                             AS avg_customer_spend,
    ROUND(cs.total_spend
          - (SELECT AVG(total_spend) FROM customer_spend), 2)
                             AS amount_above_average
FROM customer_spend AS cs
INNER JOIN `aly6600-lab-1.aly6600_lab8.customer` AS c
    ON cs.customer_id = c.customer_id
WHERE cs.total_spend > (SELECT AVG(total_spend) FROM customer_spend)
ORDER BY cs.total_spend DESC;
-- 285 of 599 customers are above the $112.53 average.
-- KARL SEAL leads at $221.55, which is $109.02 above the average.


-- ============ TASK 2: CHAINED CTEs ============

-- Business question: which stores have the most above-average-spending
-- customers, and how much revenue comes from those customers?
--
-- Four chained steps, each named for what it holds:
--   customer_spend            one row per customer with their total
--   above_average_customers   only those above the average of totals
--   store_customers           those customers attached to their store
--   store_rollup              aggregated to store level
WITH customer_spend AS (
    SELECT
        customer_id,
        SUM(amount) AS total_spend
    FROM `aly6600-lab-1.aly6600_lab8.payment`
    GROUP BY customer_id
),
above_average_customers AS (
    SELECT
        customer_id,
        total_spend
    FROM customer_spend
    WHERE total_spend > (SELECT AVG(total_spend) FROM customer_spend)
),
store_customers AS (
    SELECT
        c.store_id,
        aac.customer_id,
        aac.total_spend
    FROM above_average_customers AS aac
    INNER JOIN `aly6600-lab-1.aly6600_lab8.customer` AS c
        ON aac.customer_id = c.customer_id
),
store_rollup AS (
    SELECT
        sc.store_id,
        COUNT(*)            AS above_avg_customers,
        SUM(sc.total_spend) AS revenue_from_them,
        AVG(sc.total_spend) AS avg_spend_per_customer
    FROM store_customers AS sc
    GROUP BY sc.store_id
)
SELECT
    RANK() OVER (ORDER BY sr.above_avg_customers DESC) AS store_rank,
    sr.store_id,
    ct.city                             AS store_city,
    sr.above_avg_customers,
    ROUND(sr.revenue_from_them, 2)      AS revenue_from_them,
    ROUND(sr.avg_spend_per_customer, 2) AS avg_spend_per_customer
FROM store_rollup AS sr
INNER JOIN `aly6600-lab-1.aly6600_lab8.store` AS s
    ON sr.store_id = s.store_id
INNER JOIN `aly6600-lab-1.aly6600_lab8.address` AS a
    ON s.address_id = a.address_id
INNER JOIN `aly6600-lab-1.aly6600_lab8.city` AS ct
    ON a.city_id = ct.city_id
ORDER BY sr.above_avg_customers DESC
LIMIT 5;
-- Only 2 rows return, not 5. Sakila has exactly two stores, so the
-- LIMIT is written as the brief asks and simply never binds.
-- Store 1, Lethbridge: 160 above-average customers, $21,285.61.
-- Store 2, Woodridge: 125 above-average customers, $16,738.57.
