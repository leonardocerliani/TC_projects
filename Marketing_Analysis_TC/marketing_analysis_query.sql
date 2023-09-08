/*
	Obtain session time and revenue (if any) for each user, day, session and campaign (if any).

	Session time is calculated as the amount of seconds from each session_start in a day to the 
    last event before the next session_start. Events before the first session_start in a day 
    refer to sessions started the day before, and are not considered.

	LC 15-08-2023
*/

with
-- Rank session_start per user/date and collect revenue and campaign name (if any) 
assign_session_rank as 
(
  SELECT
    user_pseudo_id,
    parse_date('%Y%m%d',event_date) as event_date,
    event_timestamp,
    FORMAT_TIMESTAMP('%T', TIMESTAMP_MICROS(event_timestamp)) AS formatted_time,
    event_name,
		purchase_revenue_in_usd as revenue,

    -- Assign session rank
    case when event_name="session_start" then
      rank() over (partition by user_pseudo_id, event_date order by event_timestamp)
      else NULL end as session_start_rank,
    
    -- Record if there was a campaign in _any_ event_name
    case when campaign like "NewYear%" or campaign like "BlackFriday%" 
      or campaign like "Holiday%" or campaign = "Data Share Promo" or campaign like "%data%" 
    then campaign else NULL 
    end as campaign

  FROM
    `turing_data_analytics.raw_events`
  -- WHERE user_pseudo_id in ("10731965.6220509788") -- for testing only
),

-- Use the rank of each session_start in a day/user to label all the other events in that session
assign_session_label as
(
  select 
    *, 
	max(session_start_rank) over (partition by user_pseudo_id, event_date order by event_timestamp) as session_label
  from assign_session_rank
),

-- Use the primary key defined by user_pseudo_id, event_date, session_label, campaign to calculate
-- session length and sum of revenue for each session
calculate_session_length_and_revenue as
(
  select
    user_pseudo_id, event_date, session_label,
    round((max(event_timestamp) - min(event_timestamp))/1e6) as session_length,
    case when campaign IS NULL then "none" else campaign end as campaign,
    sum(revenue) as revenue,
  from 
    assign_session_label
  group by user_pseudo_id, event_date, session_label, campaign
)

-- Main query
select 
  user_pseudo_id,
  event_date,
  -- session_label,
  session_length,
  campaign,
  revenue
from calculate_session_length_and_revenue

-- EOF