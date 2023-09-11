-- 1. What is the total amount each customer spent at the restaurant?
SELECT s.customer_id, SUM(m.price) AS total_amount
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
GROUP BY 1
ORDER BY 2 DESC;

-- 2. How many days has each customer visited the restaurant?
SELECT customer_id, COUNT (DISTINCT order_date) AS number_of_days
FROM sales
GROUP BY 1;

-- 3. What was the first item from the menu purchased by each customer?
SELECT s.customer_id, m.product_name
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
WHERE (s.customer_id, s.order_date) IN (
	SELECT customer_id, MIN(order_date)
	FROM sales
	GROUP BY 1
)
GROUP BY 1,2
ORDER BY 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT m.product_name, COUNT(s.product_id) AS number_of_purchases
FROM menu m
JOIN sales s
ON m.product_id = s.product_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 1;

-- -- 5. Which item was the most popular for each customer?
WITH ranked_items AS (
	SELECT s.customer_id AS customer, 
		m.product_name AS item, 
		COUNT(s.product_id) AS number_of_purchases,
		RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(s.product_id) DESC) AS item_rank
	FROM menu m
	JOIN sales s
	ON m.product_id = s.product_id
	GROUP BY 1,2
	)

SELECT customer, item, number_of_purchases
FROM ranked_items
WHERE item_rank=1;

-- 6. Which item was purchased first by the customer after they became a member?
WITH CustomerFirstPurchase AS (
	SELECT members.customer_id, MIN(sales.order_date) AS first_purchase_date
	FROM members
	JOIN sales ON members.customer_id = sales.customer_id
    WHERE members.join_date < sales.order_date
    GROUP BY members.customer_id
	)

SELECT cfp.customer_id, 
		m.product_name AS first_purchase_product,
		cfp.first_purchase_date
FROM CustomerFirstPurchase cfp
JOIN sales s ON cfp.customer_id = s.customer_id
            AND cfp.first_purchase_date = s.order_date
JOIN menu m ON s.product_id = m.product_id;

-- 7. Which item was purchased just before the customer became a member?
WITH CustomerFirstPurchase AS (
	SELECT members.customer_id, MAX(sales.order_date) AS first_purchase_date
	FROM members
	JOIN sales ON members.customer_id = sales.customer_id
    WHERE members.join_date > sales.order_date
    GROUP BY members.customer_id
	)

SELECT cfp.customer_id, 
		m.product_name AS first_purchase_product,
		cfp.first_purchase_date
FROM CustomerFirstPurchase cfp
JOIN sales s ON cfp.customer_id = s.customer_id
            AND cfp.first_purchase_date = s.order_date
JOIN menu m ON s.product_id = m.product_id;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT members.customer_id, 
	COUNT(sales.product_id) total_items, 
	SUM(menu.price) total_amount_spent
FROM members
JOIN sales ON members.customer_id = sales.customer_id
JOIN menu ON sales.product_id = menu.product_id
WHERE members.join_date > sales.order_date
GROUP BY 1;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - 
-- how many points would each customer have?
SELECT s.customer_id, 
		SUM
			(CASE WHEN m.product_name = 'sushi' THEN m.price*10*2 
				ELSE m.price*10
				END) AS points
FROM sales s  
JOIN menu m ON s.product_id = m.product_id
GROUP BY 1;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
-- not just sushi - how many points do customer A and B have at the end of January?

-- CTE for sales data within 7 days after the customer joined
WITH SalesWithin7DaysAfterJoin AS (
    SELECT
        m.customer_id,
        s.order_date
    FROM sales s
    JOIN members m ON s.customer_id = m.customer_id
    WHERE s.order_date >= m.join_date
      AND s.order_date <= m.join_date + INTERVAL '7 days'
),

-- CTE for sales data from customer's join date till the end of January
SalesAfterFirstWeek AS (
    SELECT
        m.customer_id,
        s.order_date
    FROM sales s
    JOIN members m ON s.customer_id = m.customer_id
    WHERE s.order_date >= (m.join_date + INTERVAL '7 days')
      AND s.order_date <= '2021-01-31'::date
)

-- Main query
SELECT
	members.customer_id,
    SUM(
		CASE
			WHEN sales.order_date IN (SELECT order_date FROM SalesWithin7DaysAfterJoin) THEN menu.price * 20
			WHEN sales.order_date IN (SELECT order_date FROM SalesAfterFirstWeek) THEN menu.price * 10
    	END) AS points
FROM menu
JOIN sales ON sales.product_id = menu.product_id
JOIN members ON members.customer_id = sales.customer_id
GROUP BY members.customer_id;

-- Bonus Question 1. JOIN all things
-- For this query, I'm supposed to present customer_id, order_date, product_name, price of the product
-- and a column to show if the purchase was made when the customer was a member or not

SELECT 
	sales.customer_id,
	sales.order_date,
	menu.product_name,
	menu.price,
	CASE WHEN members.join_date < sales.order_date THEN 'Y'
		ELSE 'N' END AS member
FROM sales
LEFT JOIN members ON sales.customer_id = members.customer_id
JOIN menu ON sales.product_id = menu.product_id
ORDER BY 1;

-- Bonus Question 2. RANK all things
-- -- In this table, present customer_id, order_date, product_name, price of the product,
-- a column to show if the purchase was made when the customer was a member or not, and rank by
-- order_date for purchases for each customer when they joined the loyalty program

WITH t1 AS (
	SELECT 
		sales.customer_id,
		sales.order_date,
		menu.product_name,
		menu.price,
		CASE WHEN members.join_date < sales.order_date THEN 'Y'
			ELSE 'N' END AS member
	FROM sales
	LEFT JOIN members ON sales.customer_id = members.customer_id
	JOIN menu ON sales.product_id = menu.product_id
	ORDER BY 1)

SELECT customer_id, order_date, product_name, price, member,
		CASE WHEN member = 'Y' THEN RANK() OVER (PARTITION BY customer_id, member ORDER BY order_date)
			ELSE NULL END AS ranking
FROM t1
ORDER BY 1;
