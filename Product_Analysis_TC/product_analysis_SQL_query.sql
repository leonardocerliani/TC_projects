/*
    Query to extract session length data from the Google Merchandise Store.
    For each user and date, the session of interested was defined by the 
    first session_start event and the first purchase event of that day.

    Various other features are also extracted and later saved in a csv file
    with the aim of conducting an analysis of session length and its association
    with other interesting feature (e.g. total due in US$)
*/

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
    -- [count actions]
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