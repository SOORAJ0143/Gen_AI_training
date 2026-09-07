-- =============================================================================
-- STUDENT GRADED PORTFOLIO LAB: 20 ADVANCED SQL INTERVIEW PROBLEMS
-- DATABASE: enterprise_retail_db
-- INSTRUCTIONS: Write optimal SQL queries for each task. Push to GitHub as .sql
-- =============================================================================

USE enterprise_retail_db;

-- -----------------------------------------------------------------------------
-- PART A: JOINS, ADVANCED FILTERING & SUBQUERIES (Q1 - Q5)
-- -----------------------------------------------------------------------------

-- [Q1] Find all customers from 'USA' who placed completed orders in Q1 2024 (Jan–Mar).
--      Return customer_name, order_id, order_date, and order net revenue.
-- YOUR QUERY HERE:
SELECT
    c.customer_name,
    o.order_id,
    o.order_date,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS net_revenue
FROM customers c
JOIN orders o        ON o.customer_id = c.customer_id
JOIN order_items oi  ON oi.order_id  = o.order_id
WHERE c.country = 'USA'
  AND o.order_status = 'Completed'
  AND o.order_date BETWEEN '2024-01-01' AND '2024-03-31'
GROUP BY c.customer_name, o.order_id, o.order_date
ORDER BY o.order_date;

-- [Q2] Identify all sales reps (department_id = 2) who have NEVER closed an order.
--      Use an Anti-Join pattern (LEFT JOIN + IS NULL or NOT EXISTS).
-- YOUR QUERY HERE:
SELECT e.employee_id, e.first_name, e.last_name
FROM employees e
WHERE e.department_id = 2
  AND NOT EXISTS (
        SELECT 1
        FROM orders o
        WHERE o.sales_rep_id = e.employee_id
          AND o.order_status = 'Completed'
  );



-- [Q3] List all products that have never been ordered in the entire history of the company.
-- YOUR QUERY HERE:
SELECT p.product_id, p.product_name
FROM products p
WHERE NOT EXISTS (
        SELECT 1 FROM order_items oi WHERE oi.product_id = p.product_id
);
 


-- [Q4] Find all employees whose salary is strictly higher than the average salary of their department.
--      Display employee name, department name, salary, and the department average salary.
-- YOUR QUERY HERE:
SELECT
    CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
    d.department_name,
    e.salary,
    ROUND(dept_avg.avg_salary, 2) AS dept_avg_salary
FROM employees e
JOIN departments d ON d.department_id = e.department_id
JOIN (
        SELECT department_id, AVG(salary) AS avg_salary
        FROM employees
        GROUP BY department_id
     ) dept_avg ON dept_avg.department_id = e.department_id
WHERE e.salary > dept_avg.avg_salary;

-- [Q5] Find all customer segments where the total net revenue exceeds $30,000 across completed orders.
--      Display segment, total orders count, and net revenue sorted descending.
-- YOUR QUERY HERE:
SELECT
    CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
    d.department_name,
    e.salary,
    ROUND(dept_avg.avg_salary, 2) AS dept_avg_salary
FROM employees e
JOIN departments d ON d.department_id = e.department_id
JOIN (
        SELECT department_id, AVG(salary) AS avg_salary
        FROM employees
        GROUP BY department_id
     ) dept_avg ON dept_avg.department_id = e.department_id
WHERE e.salary > dept_avg.avg_salary;



-- -----------------------------------------------------------------------------
-- PART B: COMMON TABLE EXPRESSIONS (CTEs) & COMPLEX LOGIC (Q6 - Q8)
-- -----------------------------------------------------------------------------

-- [Q6] Using a CTE, calculate the Total Spend per customer. In the main query,
--      classify customers into 'High Spender' (>= $20k), 'Mid Spender' ($5k-$20k),
--      and 'Low Spender' (< $5k). Count the number of customers in each bracket.
-- YOUR QUERY HERE:
WITH customer_spend AS (
    SELECT
        c.customer_id,
        c.customer_name,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS total_spend
    FROM customers c
    JOIN orders o        ON o.customer_id = c.customer_id
    JOIN order_items oi  ON oi.order_id  = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY c.customer_id, c.customer_name
),
classified AS (
    SELECT *,
        CASE
            WHEN total_spend >= 20000 THEN 'High Spender'
            WHEN total_spend >= 5000  THEN 'Mid Spender'
            ELSE 'Low Spender'
        END AS spender_tier
    FROM customer_spend
)
SELECT spender_tier, COUNT(*) AS num_customers
FROM classified
GROUP BY spender_tier
ORDER BY num_customers DESC;


-- [Q7] Find customers who placed more than one completed order. Return customer_id,
--      customer_name, first order date, and most recent order date.
-- YOUR QUERY HERE:
SELECT
    c.customer_id,
    c.customer_name,
    MIN(o.order_date) AS first_order_date,
    MAX(o.order_date) AS most_recent_order_date
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_status = 'Completed'
GROUP BY c.customer_id, c.customer_name
HAVING COUNT(*) > 1;


-- [Q8] Using a RECURSIVE CTE, generate a date series from '2024-01-01' to '2024-01-10'
--      and count how many orders were placed on each calendar day (including 0-order days).
-- YOUR QUERY HERE:
SELECT
    c.customer_id,
    c.customer_name,
    MIN(o.order_date) AS first_order_date,
    MAX(o.order_date) AS most_recent_order_date
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_status = 'Completed'
GROUP BY c.customer_id, c.customer_name
HAVING COUNT(*) > 1;



-- -----------------------------------------------------------------------------
-- PART C: RANKING WINDOW FUNCTIONS (Q9 - Q12)
-- -----------------------------------------------------------------------------

-- [Q9] Find the highest paid employee in EACH department without using GROUP BY or subquery filters.
--      Use DENSE_RANK() or ROW_NUMBER() in a CTE.
-- YOUR QUERY HERE:
WITH RANKED AS(
SELECT 
        e.employee_id, e.first_name, e.last_name, e.salary, e.department_id,
        DENSE_RANK() OVER (PARTITION BY e.department_id ORDER BY e.salary DESC) AS salary_rank
    FROM employees e
)
SELECT r.employee_id, r.first_name, r.last_name, d.department_name, r.salary
FROM ranked r
JOIN departments d ON d.department_id = r.department_id
WHERE r.salary_rank = 1;



-- [Q10] (Deduplication Simulation) If duplicate orders existed, how would you pick only
--       the earliest order per customer? Write a query using ROW_NUMBER() partitioned
--       by customer_id ordered by order_date ASC.
-- YOUR QUERY HERE:
WITH dedup AS (
    SELECT
        o.*,
        ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.order_date ASC) AS rn
    FROM orders o
)
SELECT order_id, customer_id, order_date
FROM dedup
WHERE rn = 1
ORDER BY customer_id;


-- [Q11] Divide all products into 4 equal price quartiles using NTILE(4) based on unit_price.
--       Display product_name, unit_price, and price_quartile (1 = lowest, 4 = highest).
-- YOUR QUERY HERE:
SELECT
    product_name,
    unit_price,
    NTILE(4) OVER (ORDER BY unit_price) AS price_quartile
FROM products
ORDER BY unit_price;


-- [Q12] Rank all products by unit_price within their category using both RANK() and DENSE_RANK()
--       to demonstrate how ties are treated.
-- YOUR QUERY HERE:
SELECT
    p.product_name,
    c.category_name,
    p.unit_price,
    RANK()       OVER (PARTITION BY p.category_id ORDER BY p.unit_price DESC) AS price_rank,
    DENSE_RANK() OVER (PARTITION BY p.category_id ORDER BY p.unit_price DESC) AS price_dense_rank
FROM products p
JOIN categories c ON c.category_id = p.category_id
ORDER BY c.category_name, p.unit_price DESC;



-- -----------------------------------------------------------------------------
-- PART D: OFFSET FUNCTIONS: LAG & LEAD (Q13 - Q15)
-- -----------------------------------------------------------------------------

-- [Q13] (Month-over-Month Growth) Calculate the total net revenue for each calendar month,
--       and use LAG() to compute the previous month's revenue and the MoM Dollar Growth.
-- YOUR QUERY HERE:
WITH monthly AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS net_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT
    order_month,
    ROUND(net_revenue, 2) AS net_revenue,
    ROUND(LAG(net_revenue) OVER (ORDER BY order_month), 2) AS prev_month_revenue,
    ROUND(net_revenue - LAG(net_revenue) OVER (ORDER BY order_month), 2) AS mom_dollar_growth
FROM monthly
ORDER BY order_month;


-- [Q14] (Customer Inactivity Interval) For each customer, list all their orders in chronological
--       order and use LAG() to calculate the days elapsed since their previous order.
-- YOUR QUERY HERE:
SELECT
    o.customer_id,
    o.order_id,
    o.order_date,
    LAG(o.order_date) OVER (PARTITION BY o.customer_id ORDER BY o.order_date) AS prev_order_date,
    DATEDIFF(
        o.order_date,
        LAG(o.order_date) OVER (PARTITION BY o.customer_id ORDER BY o.order_date)
    ) AS days_since_prev_order
FROM orders o
ORDER BY o.customer_id, o.order_date;


-- [Q15] For each order, display the current order's date, customer_id, and use LEAD()
--       to show the date of that customer's next upcoming order.
-- YOUR QUERY HERE:
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    LEAD(o.order_date) OVER (PARTITION BY o.customer_id ORDER BY o.order_date) AS next_order_date
FROM orders o
ORDER BY o.customer_id, o.order_date;



-- -----------------------------------------------------------------------------
-- PART E: AGGREGATE WINDOW FUNCTIONS & FRAMES (Q16 - Q20)
-- -----------------------------------------------------------------------------

-- [Q16] (Running Total) Calculate a running cumulative total of net revenue ordered chronologically
--       by order_date across all completed orders.
-- YOUR QUERY HERE:
WITH order_revenue AS (
    SELECT
        o.order_id,
        o.order_date,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS order_net_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.order_id, o.order_date
)
SELECT
    order_id,
    order_date,
    ROUND(order_net_revenue, 2) AS order_net_revenue,
    ROUND(SUM(order_net_revenue) OVER (
        ORDER BY order_date, order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) AS running_total
FROM order_revenue
ORDER BY order_date, order_id;


-- [Q17] (3-Day Moving Average) For each order date, calculate the daily revenue and a 3-day
--       moving average (current day and 2 preceding days) using ROWS BETWEEN 2 PRECEDING AND CURRENT ROW.
-- YOUR QUERY HERE:
WITH daily AS (
    SELECT
        o.order_date,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS daily_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.order_date
)
SELECT
    order_date,
    ROUND(daily_revenue, 2) AS daily_revenue,
    ROUND(AVG(daily_revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_3day
FROM daily
ORDER BY order_date;



-- [Q18] (Percentage of Total) For each product sold in completed orders, display product_name,
--       category_name, product revenue, and calculate what percentage that product contributes
--       to its parent category's total revenue.
-- YOUR QUERY HERE:
WITH product_rev AS (
    SELECT
        p.product_id, p.product_name, c.category_id, c.category_name,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS product_revenue
    FROM order_items oi
    JOIN orders o      ON o.order_id = oi.order_id
    JOIN products p    ON p.product_id = oi.product_id
    JOIN categories c  ON c.category_id = p.category_id
    WHERE o.order_status = 'Completed'
    GROUP BY p.product_id, p.product_name, c.category_id, c.category_name
)
SELECT
    product_name,
    category_name,
    ROUND(product_revenue, 2) AS product_revenue,
    ROUND(100.0 * product_revenue / SUM(product_revenue) OVER (PARTITION BY category_id), 2) AS pct_of_category
FROM product_rev
ORDER BY category_name, pct_of_category DESC;



-- [Q19] Calculate the difference between each employee's salary and the highest salary
--       in their department using MAX() OVER (PARTITION BY ...).
-- YOUR QUERY HERE:
SELECT
    CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
    d.department_name,
    e.salary,
    MAX(e.salary) OVER (PARTITION BY e.department_id) AS dept_max_salary,
    MAX(e.salary) OVER (PARTITION BY e.department_id) - e.salary AS salary_gap
FROM employees e
JOIN departments d ON d.department_id = e.department_id
ORDER BY d.department_name, salary_gap;


-- [Q20] (Executive Retention Challenge) Identify customers who placed orders in two consecutive
--       months in 2024. Return distinct customer_id and customer_name.
-- YOUR QUERY HERE:
WITH monthly_orders AS (
    SELECT DISTINCT
        o.customer_id,
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month
    FROM orders o
    WHERE YEAR(o.order_date) = 2024
),
with_next AS (
    SELECT
        customer_id,
        order_month,
        LEAD(order_month) OVER (PARTITION BY customer_id ORDER BY order_month) AS next_month
    FROM monthly_orders
)
SELECT DISTINCT w.customer_id, c.customer_name
FROM with_next w
JOIN customers c ON c.customer_id = w.customer_id
WHERE w.next_month = DATE_FORMAT(
        DATE_ADD(STR_TO_DATE(CONCAT(w.order_month, '-01'), '%Y-%m-%d'), INTERVAL 1 MONTH),
        '%Y-%m'
      );