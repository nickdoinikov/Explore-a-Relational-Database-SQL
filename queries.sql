/* Query 1 - query used for the first insight */

SELECT month,
       SUM(Family_friendly)*100/(SUM(Family_friendly)+SUM(Other)) AS Family_Friendly,
       SUM(Other)*100/(SUM(Family_friendly)+SUM(Other)) AS Other
 FROM (
        SELECT DATE_PART('month',rental.rental_date) AS month,
               rental.rental_date,
               film.title title,
               CASE WHEN category.name IN ('Animation','Children','Classics','Family','Music')
                    THEN 1
                    ELSE 0
                    END AS Family_friendly,
               CASE WHEN category.name NOT IN ('Animation','Children','Classics','Family','Music')
                    THEN 1
                    ELSE 0
                    END AS Other
        FROM rental
          JOIN inventory
            ON rental.inventory_id = inventory.inventory_id
          JOIN film
            ON film.film_id = inventory.film_id
          JOIN film_category
            ON film_category.film_id = film.film_id
          JOIN category
            ON category.category_id = film_category.category_id
          ) sub
  GROUP BY 1
  ORDER BY 1

/* Query 2 - query used for the second insight */

WITH top_1 as     (SELECT actor.actor_id id,
                       CONCAT(actor.first_name,' ',actor.last_name) AS full_name,
                       COUNT(rental.rental_id) AS rental_count
                   FROM actor
                   JOIN film_actor
                     ON actor.actor_id = film_actor.actor_id
                   JOIN film
                     ON film.film_id = film_actor.film_id
                   JOIN inventory
                     ON inventory.film_id = film.film_id
                   JOIN rental
                     ON rental.inventory_id = inventory.inventory_id
                  GROUP BY 1,2
                  ORDER BY 3 DESC
                  LIMIT 1)

SELECT CONCAT(actor.first_name,' ',actor.last_name) AS full_name,
       film.title,
       film.length duration
  FROM actor
  JOIN film_actor
    ON actor.actor_id = film_actor.actor_id AND actor.actor_id = (SELECT id FROM top_1)
  JOIN film
    ON film.film_id = film_actor.film_id
  ORDER BY 3 DESC
  LIMIT 10

/* Query 3 - query used for the third insight */

SELECT full_name,
        MAX(lag_difference) AS max_lag_difference
  FROM (
      SELECT payment_month,
             full_name,
             payment_amount,
             LAG(payment_amount) OVER (PARTITION BY full_name ORDER BY payment_month) AS lag_month,
             payment_amount - LAG(payment_amount) OVER (PARTITION BY full_name ORDER BY payment_month) AS lag_difference

        FROM (
                WITH top_10 AS (  SELECT customer.customer_id,
                                         CONCAT(customer.first_name,' ',customer.last_name) AS full_name,
                                         SUM(payment.amount) AS payment_amount
                                    FROM payment
                                    JOIN customer
                                      ON customer.customer_id = payment.customer_id
                                  GROUP BY 1,2
                                  ORDER BY 3 DESC
                                  LIMIT 10 )

                SELECT DATE_TRUNC('month',payment.payment_date) AS payment_month,
                       top_10.full_name,
                       COUNT(payment.payment_id) AS payment_count,
                       SUM(payment.amount) AS payment_amount
                  FROM top_10
                  JOIN payment
                    ON payment.customer_id = top_10.customer_id
                GROUP BY 1, 2
                ORDER BY 2
           ) t1
      ORDER BY 2, 1
    ) t2
    GROUP BY 1
    ORDER BY 2 DESC

/* Query 4 - query used for the fourth insight */

WITH top_category AS (SELECT category.name category,
                             COUNT(film.title) AS count_film
                        FROM category
                        JOIN film_category
                          ON category.category_id = film_category.category_id
                        JOIN film 
                          ON film.film_id = film_category.film_id
                      GROUP BY 1
                      ORDER BY 2 DESC
                      LIMIT 1 )

SELECT film.rating,
       COUNT(*) AS film_count
  FROM film 
  JOIN film_category
    ON film.film_id = film_category.film_id
  JOIN category
    ON category.category_id = film_category.category_id AND category.name = (SELECT category FROM top_category)
GROUP BY 1
