## Analysis of shipping fees in the Olist dataset

Leonardo Cerliani - 31-08-2023

### Quick Links
[Analysis report](https://airy-camera-dce.notion.site/Analysis-of-shipping-fees-in-the-Olist-dataset-658f79ecb86e4dbaa7ec03d3c2fa3990?pvs=4) _(NB: free tier server, so pictures might take a few seconds to load)_

[Final presentation](olist_presentation.pdf) in pdf

[SQL query](#sql-query) to extract various information on transactions (e.g. seller/customer location, price, freight value, shipping time)

### Main takeways
[Olist](https://olist.com/) is a brazilian e-commerce service connecting sellers and customers. We noticed in a preliminary EDA that the shipping fees are substantial by comparison with US industry standards. 

We sought to investigate the composition of the shipping fees and to devise suggestions to decrease them. In addition, we verified - given the data at hand - the potential increase in revenues and profits deriving from decreasing the shipping fees.

In brief:

- High shipping fees are the #1 reasons for cart abandonement, especially for small value orders.

- Freight ratio (FR - the proportion of shipping fees over the total due for an order) at [Olist](https://olist.com/) is very high (median = 19%) also by industry standards (10-15% in US). This is likely to seriously discourage potential customers to complete an order, as 47% of the cart abandonment are associated to high shipping fees

- A surgical reduction in freight ratio as small as 5% only for orders with 10-18% freight ratio could potentially increase profits up to 9%. This should be further explored with event-level data and later be the subject of an A/B test.

- Weight and volume are the most important factors to determine shipping fees: explore carrier which offer better prices based on these factors - instead of distance

---

### SQL query
The SQL query used to extract the relevant data used for the analysis is at the bottom of the same page, as well as below here

```sql
/* average lng/lat for each zip code prefix */
with 
geo as
(
  select
    distinct(geolocation_zip_code_prefix) zipcode,
    avg(geolocation_lat) as lat,
    avg(geolocation_lng) as lng,
  from `olist_db.olist_geolocation_dataset`
  group by geolocation_zip_code_prefix
  order by
    geolocation_zip_code_prefix
),

/* information about orders for each seller */
seller_info as 
(
  select
    distinct(sellers.seller_id),
    seller_zip_code_prefix as seller_zipcode,
    geo.lat as seller_lat, 
    geo.lng as seller_lng,
    seller_city,
    seller_state,
    order_id,
    price,
    freight_value,
    product_weight_g,
    product_length_cm * product_height_cm * product_width_cm as product_volume_cm3
  from `olist_db.olist_sellers_dataset` sellers join `olist_db.olist_order_items_dataset` items
    on sellers.seller_id = items.seller_id
  join geo on sellers.seller_zip_code_prefix = geo.zipcode
  join `olist_db.olist_products_dataset` products on items.product_id = products.product_id
),

/* customer data */
customer_info as
(
  select
    distinct(cust.customer_id),
    customer_zip_code_prefix as customer_zipcode,
    customer_city,
    customer_state,
    order_id,
    date(order_purchase_timestamp) as date_purchased,
    date(order_delivered_customer_date) as date_delivered,
    geo.lat as customer_lat,
    geo.lng as customer_lng
  from 
    `olist_db.olist_customesr_dataset` cust join `olist_db.olist_orders_dataset` orders
      on cust.customer_id = orders.customer_id
    join geo on cust.customer_zip_code_prefix = geo.zipcode
)

/* join customers and sellers on order_id */
select 
  *
from seller_info join customer_info
  on seller_info.order_id = customer_info.order_id
;
```
