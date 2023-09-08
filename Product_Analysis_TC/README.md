# Product Analysis
Analysis of session duration on the data from the [Google Merchandise Store](https://shop.googlemerchandisestore.com/) in the period between 2020-11-01 and 2021-01-30.

**[Analysis Report](https://tc-product-analysis.netlify.app/)**

All the material can be downloaded at the following links:
- [SQL query](https://tc-product-analysis.netlify.app/product_analysis_SQL_query.sql) - also available at the end of this page
- [data](https://tc-product-analysis.netlify.app/Graded_Task_Data.csv) collected using the query
- [notebook](https://tc-product-analysis.netlify.app/Graded_Task.Rmd) containing the full report and the code for the analysis.


<br>

# SQL query construction
**For the Product Analysis Graded Task**


## Selecting min session start and purchase in each user/day

```sql
WITH min_purchase AS (
  SELECT
    event_date,
    user_pseudo_id,
    MIN(event_timestamp) AS min_purchase_timestamp
  FROM
    `turing_data_analytics.raw_events`
  WHERE event_name = 'purchase'
  GROUP BY user_pseudo_id, event_date
),
min_session_start AS (
  SELECT
    event_date,
    user_pseudo_id,
    MIN(event_timestamp) AS min_session_start_timestamp
  FROM
    `turing_data_analytics.raw_events`
  WHERE
    event_name = 'session_start'
  GROUP BY user_pseudo_id, event_date
)
SELECT
  p.user_pseudo_id,
  parse_date('%Y%m%d',p.event_date) as event_date,
  -- p.min_purchase_timestamp,
  -- s.min_session_start_timestamp
  format_timestamp('%T', timestamp_micros(s.min_session_start_timestamp)) as first_session_start,
  format_timestamp('%T', timestamp_micros(p.min_purchase_timestamp)) as first_purchase,
FROM
  min_purchase p JOIN min_session_start s 
  ON p.user_pseudo_id = s.user_pseudo_id AND p.event_date = s.event_date
order by user_pseudo_id, event_date
```
    

## Rationale for feature gathering 

- In the data we will analyse we want to have as **primary key** the combination of user_pseudo_info and event_date.

- Also we want to catch information about events that happen only between the earliest session_start and the earliest purchase

- Many information are already in the row containing purchase events, however other information we might want to retrieve are in rows with other event names. For instance, we want to count the number of event between the earliest session_start and the earliest purchase, e.g. page_view or scroll

To deal with these requirement we proceed as follows:

We enforce our primary key by grouping by user_pseudo_id and event_date, as well as by min_session_start and min_purchase. This is because we _already_ choose the latter two in the initial CTEs and placed them into two separate columns, therefore there is only one row for each user containing these two information

```sql
/*
    Query to extract session length data from the Google Merchandise Store.
    For each user and date, the session of interested was defined by the 
    first session_start event and the first purchase event of that day.

    Various other features are also extracted and later saved in a csv file
    with the aim of conducting an analysis of session length and its association
    with other interesting feature (e.g. total due in US$)
*/

select
	t1.user_pseudo_id,
	parse_date('%Y%m%d', t1.event_date) as event_date,
	t1.min_session_start_timestamp,
	t2.min_purchase_timestamp,
	-- ...
	group by t1.user_pseudo_id, t1.event_date, t1.min_session_start_timestamp, t2.min_purchase_timestamp
```

Then we limit the information we catch between the boundaries of the earliest session_start and the earliest purchase. This is achieved with the final `where` clause.

**NB: we also enforce that the earliest purchase should occur *****after***** the earliest session_start, so that we avoid catching events in a session that was started before the midnight of the day before** 

```sql
where t2.min_purchase_timestamp > t1.min_session_start_timestamp 
  and (mt.event_timestamp >= t1.min_session_start_timestamp and mt.event_timestamp <= t2.min_purchase_timestamp) 
```

**At this point we are free to select from any of the available events withing the time boundaries,** simply by using an aggregation on a `case when`. For instance:

```sql
# selects the campaign in the event_name "purchase". Note that it is a string, so we want to use the MAX aggregation
max(case when event_name = "purchase" then mt.campaign else NULL end) as campaign,
```

An interesting case is when we want to retrieve an information which is ****not**** in either the session_start or purchase event. For instance, we want to know whether the items added to the cart come from the Sale page - hence with discounted price - or from one of the specific categories (e.g. Apparel) - hence without discount. Therefore in this case we need to look into events with name add_to_cart

```sql
sum(case when (event_name = "add_to_cart" and page_title like "%Sale%") then 1 else 0 end) as is_on_sale,
```

Importantly, now we can count the events for each event_name, for instance:

```sql
sum(case when event_name = "scroll" then 1 else 0 end) as n_scrolls,
sum(case when event_name = "add_payment_info" then 1 else 0 end) as n_add_payment_info,
sum(case when event_name = "add_shipping_info" then 1 else 0 end) as n_add_shipping_info,
sum(case when event_name = "begin_checkout" then 1 else 0 end) as n_begin_checkout,
```

## Complete query

```sql
with
-- Retrieve the min(session_start) event for each user/day
min_session_start as
(
  select
    distinct(user_pseudo_id),
    event_date,
    min(event_timestamp) as min_session_start_timestamp 
  from `turing_data_analytics.raw_events`
  where event_name = "session_start"
  group by user_pseudo_id, event_date
),
-- Retrieve the min(purchase) event for each user/day
min_purchase as
(
  select
    distinct(user_pseudo_id),
    event_date,
    min(event_timestamp) as min_purchase_timestamp,
  from `turing_data_analytics.raw_events`
  where event_name = "purchase"
  group by user_pseudo_id, event_date
),
-- extract features of interest from the main table (mt)
extract_features as
(
  select 
    t1.user_pseudo_id,
    parse_date('%Y%m%d', t1.event_date) as event_date,
    t1.min_session_start_timestamp,
    t2.min_purchase_timestamp,
    max(mt.country) as country,
    max(mt.category) as device,
    max(operating_system) as OS,
    max(browser) as browser,
    max(case when event_name = "purchase" then mt.campaign else NULL end) as campaign,
    sum(case when event_name = "purchase" then mt.total_item_quantity else 0 end) as n_items,
    sum(case when event_name = "purchase" then purchase_revenue_in_usd else 0 end) as total_due,
    sum(case when (event_name = "purchase") then 1 else 0 end) as n_purchases, -- ckeckpoint: all rows should be = 1
    sum(case when (event_name = "add_to_cart" and page_title like "%Sale%") then 1 else 0 end) as is_on_sale,
    -- [count events]
    sum(case when event_name = "scroll" then 1 else 0 end) as n_scrolls,
    sum(case when event_name = "add_payment_info" then 1 else 0 end) as n_add_payment_info,
    sum(case when event_name = "add_shipping_info" then 1 else 0 end) as n_add_shipping_info,
    sum(case when event_name = "begin_checkout" then 1 else 0 end) as n_begin_checkout,
    sum(case when event_name = "page_view" then 1 else 0 end) as n_page_view,
    sum(case when event_name = "select_item" then 1 else 0 end) as n_select_item,
    sum(case when event_name = "user_engagement" then 1 else 0 end) as n_user_engagement,
    sum(case when event_name = "view_item" then 1 else 0 end) as n_view_item,
    sum(case when event_name = "view_promotion" then 1 else 0 end) as n_view_promotion,
  from min_session_start t1 
    join min_purchase t2
      on t2.user_pseudo_id = t1.user_pseudo_id and t2.event_date = t1.event_date
    join `turing_data_analytics.raw_events` mt 
      on mt.user_pseudo_id = t2.user_pseudo_id and mt.event_date = t2.event_date
  where t2.min_purchase_timestamp > t1.min_session_start_timestamp 
    and (mt.event_timestamp >= t1.min_session_start_timestamp and mt.event_timestamp <= t2.min_purchase_timestamp) 
  group by t1.user_pseudo_id, t1.event_date, t1.min_session_start_timestamp, t2.min_purchase_timestamp
  order by event_date, user_pseudo_id
)
-- compute the session duration and convert the timestamps to HH:MM:SS
select
  *,
  timestamp_diff(
    timestamp_micros(min_purchase_timestamp), 
    timestamp_micros(min_session_start_timestamp), 
    SECOND
  ) AS TTP, # time to purchase: seconds spent from session_start to purchase
  format_timestamp('%H:%M:%S', timestamp_micros(min_session_start_timestamp)) as min_session_start_time,
  format_timestamp('%H:%M:%S', timestamp_micros(min_purchase_timestamp)) as min_purchase_time,
from extract_features
;
```
