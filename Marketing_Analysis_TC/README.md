# Analysis of marketing campaign performance

Analysis of marketing campaign performance on the data from the [Google Merchandise Store](https://shop.googlemerchandisestore.com/) in the period between 2020-11-01 and 2021-01-30.

[**Analysis report**](https://tc-marketing-analysis.netlify.app/) -  which will be used for the presentation


All the material can be downloaded from the [Github repo](https://github.com/leonardocerliani/Marketing_Analysis_TC/tree/main):

- [SQL query](https://github.com/leonardocerliani/Marketing_Analysis_TC/blob/main/marketing_analysis_query.sql) - also available at the end of this page
- data collected using the query (all csv files)
- [notebook](https://github.com/leonardocerliani/Marketing_Analysis_TC/blob/main/Marketing_Analysis_Graded_Task_V3.Rmd) containing the full report and the code for the analysis.


# SQL query construction

## Identifying sessions
The database does not contain unequivocal information about the start and the end of a session, therefore we had to devise a suitable procedure for the existing data. In brief:

- The session_start event was chosen to define the start of the session. Within the same day, different events with `event_name="session_start"` were assigned a rank according to their timestamp
- Every other event before the next session_start was labelled with this rank
- Session length was calculated as the difference in seconds between the session_start event and the last event before the subsequent session_start
- Events with no rank are those which belong to sessions started the day before, and were therefore not further considered

Implementation:

1. First filter the events with the name `”session_start”` and rank them according to event_timestamp  
```sql
case when event_name="session_start" then
  rank() over (partition by user_pseudo_id, event_date order by event_timestamp)
  else NULL end as session_start_rank,
```

2. Label all the other events in the session accordingly
```sql
max(session_start_rank) over (partition by user_pseudo_id, event_date order by event_timestamp) as session_label
```

3. At this point I have defined a **primary key** for my observations, which is given by:
- `user_pseudo_id`
- `event_date`
- `session_label`
- `campaign`

4. Now I can use this primary key to calculate Session length and Revenue per session and per campaign (or no campaign)
```sql
round((max(event_timestamp) - min(event_timestamp))/1e6) as session_length,
sum(revenue) as revenue,
```

The complete query reads as follows:
```sql
/*
	Obtain session time and revenue (if any) for each user, day, session and campaign (if any).

	Session time is calculated as the amount of seconds from each session_start in a day to the last event before the next session_start. Events before the first session_start in a day refer to sessions started the day before, and are not considered.

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
```


## Threshold session length

The analysis was carried out with different session lengths, namely 20', 60', 120' and no limit (within the same day). The results were comparable across these ranges.

At the same time, we decided to run the main analysis - and report the results - for sessions up to 60 minutes. The reasons for that are:

- the median length for a session with a purchase is ~ 19 minutes
- in a previous product analysis, we saw an increase in order value up to 30-60 minutes max
- a threshold of 60' includes 80% of all sessions

These reasons are based on the fact that we are interested in assessing the association between session length and revenue. Note however that from the previous product analysis it appeared that session length generally is not a strong predictor of total revenue.


