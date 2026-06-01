create database if not exists supply_chain_db ;
use supply_chain_db;
show databases;
CREATE TABLE datacosupplychain_clean (
    type VARCHAR(50),
    days_for_shipping_real INT,
    days_for_shipment_scheduled INT,
    benefit_per_order DECIMAL(10,2),
    sales_per_customer DECIMAL(10,2),
    delivery_status VARCHAR(50),
    late_delivery_risk TINYINT,
    category_id INT UNSIGNED,
    category_name VARCHAR(100),
    customer_city VARCHAR(100),
    customer_country VARCHAR(100),
    customer_email VARCHAR(150),
    customer_fname VARCHAR(100),
    customer_id INT UNSIGNED,
    customer_lname VARCHAR(100),
    customer_password VARCHAR(100),
    customer_segment VARCHAR(50),
    customer_state VARCHAR(100),
    customer_street VARCHAR(200),
    customer_zipcode VARCHAR(20),
    department_id INT UNSIGNED,
    department_name VARCHAR(100),
    latitude DECIMAL(10,6),
    longitude DECIMAL(10,6),
    market VARCHAR(50),
    order_city VARCHAR(100),
    order_country VARCHAR(100),
    order_customer_id INT UNSIGNED,
    order_date_dateorders DATETIME,
    order_id INT UNSIGNED,
    order_item_cardprod_id INT UNSIGNED,
    order_item_discount DECIMAL(10,2),
    order_item_discount_rate DECIMAL(5,4),
    order_item_id INT UNSIGNED,
    order_item_product_price DECIMAL(10,2),
    order_item_profit_ratio DECIMAL(6,4),  -- can be negative
    order_item_quantity INT UNSIGNED,
    sales DECIMAL(10,2),
    order_item_total DECIMAL(10,2),
    order_profit_per_order DECIMAL(10,2), -- can be negative
    order_region VARCHAR(100),
    order_state VARCHAR(100),
    order_status VARCHAR(50),
    product_card_id INT UNSIGNED,
    product_category_id INT UNSIGNED,
    product_image TEXT,
    product_name VARCHAR(200),
    product_price DECIMAL(10,2),
    product_status VARCHAR(50),
    shipping_date_dateorders DATETIME,
    shipping_mode VARCHAR(50),
    order_year INT UNSIGNED,
    order_month INT UNSIGNED,
    order_month_name VARCHAR(20),
    order_quarter INT UNSIGNED,
    order_dayofweek VARCHAR(20),
    delivery_gap_days INT,              -- can be negative
    profit_margin_pct DECIMAL(10,2),    -- can be negative
    is_late_delivery TINYINT,
    order_size_tier VARCHAR(50)
);
SHOW VARIABLES LIKE 'secure_file_priv';

SET GLOBAL local_infile = 1;

LOAD DATA INFILE 'clean_mysql_ready.csv'
INTO TABLE datacosupplychain_clean
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM datacosupplychain_clean;

SELECT 
    COUNT(*) AS total_rows,
    COUNT(order_date_dateorders) AS valid_dates
FROM datacosupplychain_clean;

SELECT *
FROM datacosupplychain_clean
WHERE order_date_dateorders IS NULL
LIMIT 10;

SELECT *
FROM datacosupplychain_clean
WHERE shipping_date_dateorders IS NULL
LIMIT 10;

SELECT 
    MIN(order_date_dateorders) AS min_order_date,
    MAX(order_date_dateorders) AS max_order_date
FROM datacosupplychain_clean;

SELECT 
    MIN(order_profit_per_order), 
    MAX(order_profit_per_order)
FROM datacosupplychain_clean;

#Q1   BASIC    Total Revenue, Profit, and Order Count
#Business Purpose: What is the overall size of this supply chain business?
select 
count(*) as Total_Orders,
Round(sum(sales),2) as Total_Revenue,
Round(sum(order_profit_per_order),2) as Total_Profit,
Round(avg(sales),2) as Average_order_value,
Round(avg(order_profit_per_order),2) as Average_Profit_per_order,
Round(sum(order_profit_per_order)/nullif(sum(sales),0)*100,2) as overall_margin_pct
From datacosupplychain_clean;

#Q2   BASIC    Revenue and Profit by Product Category
#Business Purpose: Which product categories are most valuable to the business?

select
category_name,
count(*) as Total_Orders,
Round(sum(sales),2) as Total_Revenue,
Round(sum(order_profit_per_order),2) as Total_Profit,
Round(sum(order_profit_per_order)/NULLIF(sum(sales),0)*100,2) as Overall_Margin_pct
from datacosupplychain_clean
group by category_name
order by total_Revenue
limit 10;

#Top 5 Products by Sales
select product_name,
sum(sales)as total_revenue
from datacosupplychain_clean
group by product_name
order by total_revenue desc
limit 5;

#Average Lead Time by Shipping Mode
SELECT 
    shipping_mode,
    AVG(DATEDIFF(shipping_date_dateorders, order_date_dateorders)) AS avg_lead_time
FROM datacosupplychain_clean
GROUP BY shipping_mode;





#Late Delivery Rate by Shipping Mode
#Business Purpose: Which shipping modes are failing customers most often?
select 
shipping_mode,
count(*) as total_orders,
sum(case when delivery_status ="Late Delivery"
then 1 else 0 end) as late_orders,
Round(sum(case when delivery_status = "Late delivery"
then 1 else 0 end)*100/count(*),2) as late_orders_pct
from datacosupplychain_clean
group by shipping_mode
order by late_orders;

#Monthly Revenue Trend
#Business Purpose: How has revenue changed month by month? Is the business growing?

select
order_year,
order_month,
order_month_name,
count(*) as total_orders,
round(sum(sales),2) as total_revenue,
round(sum(order_profit_per_order),2) as total_profit
from datacosupplychain_clean
where order_year and order_month is not null
group by order_year, order_month, order_month_name
order by order_year, order_month;

#Top 10 Most Profitable Products
#Business Purpose: Which specific products should we prioritise in inventory?
select category_name, product_name,
count(*) as total_orders,
round(sum(sales),2) as total_revenue,
round(sum(order_profit_per_order),2) as total_profit
from datacosupplychain_clean
group by category_name , product_name
order by total_profit desc;
   
# Discount Impact on Profit — Bucketed Analysis
#Business Purpose: At what discount rate does the business start losing money?

select discount_bucket,count(*) as total_orders,
Round(avg(sales),2) as Avg_revenue,
Round(avg(order_profit_per_order),2)as avg_profit,
Round(avg(order_profit_per_order)/nullif(sum(sales),0)*100,2) as avg_margin_pct,
sum(case when order_profit_per_order < 0 then 1 else 0 end)  as loss_orders,
round(sum(case WHEN order_profit_per_order < 0 THEN 1 else 0 end)*100/count(*),2) as loss_order_pct
from 
( select *, case WHEN order_item_discount_rate = 0        THEN '1. No Discount'
WHEN order_item_discount_rate <= 0.05    THEN '2. Low (1-5%)'
WHEN order_item_discount_rate <= 0.10    THEN '3. Medium (6-10%)'
WHEN order_item_discount_rate <= 0.20    THEN '4. High (11-20%)'
ELSE  '5. Very High (20%)'END AS discount_bucket
from datacosupplychain_clean)bucketed
group by discount_bucket
order by discount_bucket;


# Market Performance Scorecard
#Business Purpose: Which global markets are high revenue but also high risk?

select market,count(*) as total_orders,
round(sum(sales),2) as total_revenue,
round(avg(sales),2) as Avgerage_revenue,
round(sum(order_profit_per_order),2) as Total_margin,
round(avg(days_for_shipping_real),2) as Average_shipping_days,
round(sum(case when delivery_status = 'late_delivery' then  1 else 0 end)/count(*)*100,2) as late_rate_pct,
RANK() OVER (ORDER BY SUM(sales) DESC)       AS revenue_rank
FROM datacosupplychain_clean
GROUP BY market
ORDER BY total_revenue DESC;


#Q8  Orders Above Average Order Value
#Business Purpose: What percentage of our orders are high-value orders?
SELECT COUNT(*) AS total_orders,
SUM(CASE WHEN sales > (SELECT AVG(sales) FROM datacosupplychain_clean)THEN 1 ELSE 0 END) AS above_avg_orders,
ROUND(SUM(CASE WHEN sales > (SELECT AVG(sales) FROM datacosupplychain_clean)THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS above_avg_pct,
ROUND((SELECT AVG(sales) FROM datacosupplychain_clean), 2) AS average_order_value
FROM datacosupplychain_clean;

# High Profit Orders (> avg profit)
select count(*) as total_orders,
sum(order_profit_per_order>avg_profit )as above_avg_profit,
round(sum(order_profit_per_order> avg_profit) * 100 /count(*),2) as above_avg_profit_pct
from datacosupplychain_clean, (select avg(order_profit_per_order)  as avg_profit from datacosupplychain_clean)t


#Profit Margin by Category
select category_name,count(*), round(sum(order_profit_per_order)/count(*)*100,2) as Profit_margin_pct
from datacosupplychain_clean
group by Category_name;

#Orders Delivered Late vs On Time
select count(*), is_late_delivery
from datacosupplychain_clean
group by is_late_delivery;

#Which Region Has More Delays?
select count(*) as total_orders, order_region, sum(is_late_delivery) as delayed_orders
from datacosupplychain_clean
group by order_region
order by delayed_orders Desc;

#Category with Highest Avg Sales
SELECT 
    category_name,
    AVG(sales) AS avg_sales
FROM datacosupplychain_clean
GROUP BY category_name
ORDER BY avg_sales DESC
LIMIT 1;

#Top 10% Orders (High Value)




#Loss-making Orders %
select count(*) as total_orders,
sum(order_profit_per_order<0 ) as total_profit,
round(sum(order_profit_per_order<0)/count(*)*100,2) as total_profit_pct
from datacosupplychain_clean;

#Customer Segment Analysis with Revenue Share
#Business Purpose: What percentage of total revenue comes from each customer segment?
select customer_segment,
count(*) as total_orders,
sum(sales) as total_revenue,
sum(order_profit_per_order) as total_profit,
Round(sum(sales) / Sum(Sum(sales)) OVER () * 100, 2)   AS revenue_share_pct,
Round(Sum(order_profit_per_order)/ Sum(Sum(order_profit_per_order)) OVER () * 100, 2) AS profit_share_pct
from datacosupplychain_clean
group by customer_segment
order by total_revenue;

#Fraud Detection by Category with HAVING
#Business Purpose: Which categories have the highest suspected fraud rate?
select Category_name,count(*) as total_orders,
sum(case when order_status = 'Suspected_fraud' then 1 else 0 end) as fraud_count,
round(sum(case when order_status ='Suspected_fraud' then 1 else 0 end)/count(*)*100,2) as fraud_count_pct,
round(sum(case when order_status = 'Suspected_fraud' then sales else 0 end),2) as revenue_at_risk
from datacosupplychain_clean
group by Category_name
having sum(case when order_status = 'Suspected_fraud' then 1 else 0 end)>0;

#Running Total of Revenue Over Time
#Business Purpose: What is the cumulative revenue as each month passes?
select order_year, order_month, order_month_name ,
round(sum(sales),2) as total_revenue,
round(sum(sum(sales)) over(order by order_year, order_month
rows between unbounded preceding and current row),2) as cumulative_revenue
from datacosupplychain_clean
group by order_year, order_month, order_month_name
order by order_year , order_month;

#Orders Delivered Early vs On Time vs Late
#Business Purpose: What is the full distribution of delivery performance?

Select delivery_performance,COUNT(*)  AS order_count,ROUND(COUNT(*) * 100.0 /SUM(COUNT(*)) OVER (), 2) AS pct_of_total,
ROUND(AVG(ABS(delivery_gap_days)), 1) AS avg_days_variance from 
(select *,
case when delivery_gap_days <0 then 'Early_Delivery'
when delivery_gap_days = 0 then 'Ontime'
when delivery_gap_days <=2  then 'slightly_delayed'
else 'very_delayed'
end as delivery_performance
from datacosupplychain_clean
where delivery_gap_days is not null)perf
group by  delivery_performance
order by  delivery_performance;

FROM (
    SELECT *,
        CASE
            WHEN delivery_gap_days < 0  THEN '1. Early'
            WHEN delivery_gap_days = 0  THEN '2. Exactly On Time'
            WHEN delivery_gap_days <= 2 THEN '3. Slightly Late (1-2 days)'
            WHEN delivery_gap_days <= 5 THEN '4. Moderately Late (3-5 days)'
            ELSE                             '5. Very Late (6+ days)'
        END AS delivery_performance
    FROM supply_chain
    where delivery_gap_days is not NULL
) perf
group by delivery_performance
order by delivery_performance;

# Top 3 Products by Revenue Within Each Category
# Which are the star products in each category?
with ranking as(
select category_name, count(*)as total_order,
sum(sales) as total_revenue , product_name,rank() over(partition by category_name order by sum(sales) desc) as ranking_product
from datacosupplychain_clean
group by category_name , product_name
)
select category_name, ranking_product, product_name, total_revenue
from ranking
where ranking_product <=3

# Month-over-Month Revenue Change Using LAG
#Business Purpose: Is revenue growing or shrinking month over month?

WITH  revenue  as(
Select count(*) as total_order,
round(sum(sales),2) as total_revenue,
round(sum(order_profit_per_order),2) as total_profit,
order_year,
order_month,
order_month_name
from  datacosupplychain_clean
where order_date_dateorders is not null
group by order_year, order_month , order_month_name
)
select  total_revenue , total_profit, order_month_name,
lag(total_revenue,1) over(order by order_year , order_month ) as previous_revenue,
total_revenue - lag(total_revenue, 1) over(order by order_year, order_month ) as difference_in_revenue,
case when total_revenue > lag(total_revenue,1) over(order by order_year , order_month ) then 'Growing'
when total_revenue = lag(total_revenue,1) over(order by order_year , order_month ) then 'Flat'
else 'Declining'
end  as trend
from revenue 
order by order_year, order_month;

#Year-over-Year Delivery Performance
#Is our delivery performance getting better or worse each year?
WITH yearly_perf AS (
select order_year,count(*) AS total_orders,
round(avg(days_for_shipping_real), 2) AS avg_actual_days,
round(avg(delivery_gap_days), 2) AS avg_delay_days,
round(sum(case when delivery_status = 'Late delivery' then 1 else 0 end) * 100 / COUNT(*), 2) AS late_rate_pct
from datacosupplychain_clean
where order_date_dateorders is not null
group by order_year
)
select order_year,total_orders,avg_actual_days,late_rate_pct,
lag(late_rate_pct, 1) over (order by order_year) as prev_year_late_rate,
round(late_rate_pct - lag(late_rate_pct, 1) over (order by  order_year), 2) as late_rate_change,
case when late_rate_pct < LAG(late_rate_pct, 1) over (order by order_year) then 'Improving'
when late_rate_pct > LAG(late_rate_pct, 1) over (order by order_year) then 'Getting Worse'
else'No Change'
end as trend
from yearly_perf
order by order_year;


# Customers Who Placed Orders in 2016 but NOT in 2017 (Churn)
#Business Purpose: Which customers did we lose between 2016 and 2017?
select DISTINCT(customer_id), order_id, order_year
from datacosupplychain_clean
where order_year =  '2016' and  customer_id not in (select customer_id from datacosupplychain_clean
where order_year = '2017');

#3-Month Moving Average of Revenue
#Business Purpose: What is the smoothed revenue trend removing month-to-month noise?
with mom as (select sum(sales) as total_revenue,order_year,order_month ,order_month_name,
round(avg(sales),2) as average_revenue
from datacosupplychain_clean
where order_month is not null
group by order_year,order_month, order_month_name)
(select order_month, order_year, order_month_name,
total_revenue,
avg(total_revenue) over(order by order_month, order_year rows between 2 preceding  and current row  ) as previous_revenue
from mom 
order by order_year, order_month);


# Second Highest Revenue Category
#Business Purpose: What is our second biggest category if the top category underperforms?
with category_name as (
select category_name, 
round(sum(sales),2) as total_revenue
from datacosupplychain_clean 
group by category_name)
select category_name, total_revenue
from (
select category_name,total_revenue,
Rank() OVER ( order  BY total_revenue DESC) AS rnk
from category_name
) ranked
WHERE rnk = 2;

#Products That Are Always Profitable — Zero Loss Orders
#Business Purpose: Which products have never had a loss-making order across all transactions?
select count(*) as total_orders, product_name, category_name,
sum(sales) as total_revenue,
round(max(order_profit_per_order),2) as max_profit,
round(min(order_profit_per_order),2) as min_profit,
round(avg(order_profit_per_order),2) as avg_profit,
round(sum(order_profit_per_order),2) as total_profit
from datacosupplychain_clean
group by product_name, category_name
having min(order_profit_per_order )>0
and count(*) > 1
order by total_profit desc
limit 10;






