-- copy our info into the tables
COPY info FROM 'info.csv' DELIMITER ',' CSV HEADER;
COPY finance FROM 'finance.csv' DELIMITER ',' CSV HEADER;
COPY reviews FROM 'reviews.csv' DELIMITER ',' CSV HEADER;
COPY traffic FROM 'traffic.csv' DELIMITER ',' CSV HEADER;
COPY brands FROM 'brands.csv' DELIMITER ',' CSV HEADER;

-- missing values

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN i.description IS NULL THEN 1 ELSE 0 END) AS missing_description,
    SUM(CASE WHEN f.listing_price IS NULL THEN 1 ELSE 0 END) AS missing_listing_price,
    SUM(CASE WHEN t.last_visited IS NULL THEN 1 ELSE 0 END) AS missing_last_visited
FROM
    info i
JOIN
    finance f ON i.product_id = f.product_id
JOIN
    traffic t ON i.product_id = t.product_id;


-- nike vs adidas
WITH FilteredFinance AS (
    SELECT
        product_id,
        CAST(listing_price AS Integer) AS listing_price
    FROM
        finance
    WHERE
        listing_price > 0
),
AggregatedData AS (
    SELECT
        b.brand,
        ff.listing_price,
        COUNT(ff.product_id) AS count
    FROM
        brands b
    JOIN
        FilteredFinance ff ON b.product_id = ff.product_id
    GROUP BY
        b.brand, ff.listing_price
)

SELECT
    brand,
    listing_price,
    count
FROM
    AggregatedData
ORDER BY
    listing_price DESC;

-- price ranges
WITH CategorizedFinance AS (
    SELECT
        b.brand,
        f.product_id,
        f.revenue,
        CASE 
            WHEN f.listing_price < 42 THEN 'Budget'
            WHEN f.listing_price >= 42 AND f.listing_price < 74 THEN 'Average'
            WHEN f.listing_price >= 74 AND f.listing_price < 129 THEN 'Expensive'
            ELSE 'Elite'
        END AS price_category
    FROM
        brands b
    JOIN
        finance f ON b.product_id = f.product_id
    WHERE
        b.brand IS NOT NULL
)

SELECT
    brand,
    COUNT(product_id) AS product_count,
    SUM(revenue) AS total_revenue,
    price_category
FROM
    CategorizedFinance
GROUP BY
    brand, price_category
ORDER BY
    total_revenue DESC;

-- average discount
WITH BrandFinance AS (
    SELECT
        b.brand,
        f.discount
    FROM
        brands b
    JOIN
        finance f ON b.product_id = f.product_id
    WHERE
        b.brand IS NOT NULL
)

SELECT
    brand,
    AVG(discount) * 100 AS average_discount
FROM
    BrandFinance
GROUP BY
    brand;

-- corr between revenue and reviews
WITH RevenueReviewsCorrelation AS (
    SELECT
        f.revenue,
        r.reviews
    FROM
        finance f
    JOIN
        reviews r ON f.product_id = r.product_id
)

SELECT
    CORR(revenue, reviews) AS review_revenue_corr
FROM
    RevenueReviewsCorrelation;

-- ratings and reviews by product description length
WITH DescriptionRatings AS (
    SELECT
        TRUNC(LENGTH(i.description) / 100.0) * 100 AS description_length,
        CAST(r.rating AS numeric) AS rating
    FROM
        info i
    JOIN
        reviews r ON i.product_id = r.product_id
    WHERE
        i.description IS NOT NULL
)

SELECT
    description_length,
    ROUND(AVG(rating), 2) AS average_rating
FROM
    DescriptionRatings
GROUP BY
    description_length
ORDER BY
    description_length;

-- reviews by month and brand
WITH BrandTrafficReviews AS (
    SELECT
        b.brand,
        DATE_PART('month', t.last_visited) AS month,
        r.product_id
    FROM
        brands b
    JOIN
        traffic t ON b.product_id = t.product_id
    JOIN
        reviews r ON r.product_id = t.product_id
    WHERE
        b.brand IS NOT NULL AND
        DATE_PART('month', t.last_visited) IS NOT NULL
)

SELECT
    brand,
    month,
    COUNT(product_id) AS num_reviews
FROM
    BrandTrafficReviews
GROUP BY
    brand, month
ORDER BY
    brand, month;

-- top rev generating products
WITH HighestRevenueProduct AS
(
   SELECT i.product_name,
          b.brand,
          f.revenue
   FROM finance f
   JOIN info i ON f.product_id = i.product_id
   JOIN brands b ON b.product_id = i.product_id
   WHERE product_name IS NOT NULL
     AND revenue IS NOT NULL
     AND brand IS NOT NULL
)
SELECT product_name,
       brand,
       revenue,
       RANK() OVER (ORDER BY revenue DESC) AS product_rank
FROM HighestRevenueProduct
LIMIT 10;

-- footwear performance
WITH Footwear AS (
  SELECT 
    i.description, 
    f.revenue
  FROM info i
  JOIN finance f ON i.product_id = f.product_id
  WHERE 
    (i.description ILIKE '%shoe%' OR i.description ILIKE '%trainer%' OR i.description ILIKE '%foot%')
    AND i.description IS NOT NULL
)
SELECT 
  COUNT(*) AS num_footwear_products,
  PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY revenue) AS median_footwear_revenue
FROM Footwear;

-- clothing performance
SELECT 
  COUNT(*) AS num_clothing_products,
  PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.revenue) AS median_clothing_revenue
FROM info i
INNER JOIN finance f ON i.product_id = f.product_id
WHERE NOT EXISTS (
  SELECT 1
  FROM info i2
  WHERE i2.product_id = i.product_id
    AND (
      i2.description ILIKE '%shoe%' 
      OR i2.description ILIKE '%trainer%' 
      OR i2.description ILIKE '%foot%'
    )
)
AND i.description IS NOT NULL;

