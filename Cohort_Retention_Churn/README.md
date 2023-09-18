# Cohort retention and churn

The following is an example of how to write a simple, modular and flexible query to calculate cohort retention/churn (or their rate) in Bigquery SQL.

The dataset is very simple, containing only user ID and the dates when the subscription start (`cohort_week`) and ends (`end_week`). Weekly cohorts are defined. 

Besides the final result - displayed in Google Sheets - there are four interesting points in the logic:

- the (unpivoted) table is effectively calculated just with a double `group by`, that is by cohort week and end week. This avoids using several `case..when` clauses, which can lead to typos and consequent miscalculations

- the number of elapsed weeks in the `cohort_week` column is calculated using a simple window function. It can then be exported to Google Sheets so that it can be used to display the final retention/churn table in the standard triangular format

- several measures can be defined (i.e. retention/churn or the corresponding rate) in different lines, and uncommented when necessary to retrieve the desired measure.

- the use of the `pivot` function in native BigQuery is shown, eliminating the need to pivot the table manually in Google Sheets (although the syntax make the query less intuitive to read)

![](cohort_retention_table.jpg)


```sql
/* 
	This query generates a cohort table in standard view
  i.e. with columns for the n-th week of each cohort.

  Two cohort metrics are implemented: retention and retention rate. 
  Uncomment the one you desire to get (see "retention unpivoted table" below)
  By default, the retention rate is calculated.
*/

/* 
  The following CTEs for 
  
  - n_churns per cohort and each subsequent week 
  - # of subscribers in the first week
  - their joint table
  - calculation of different measures
  - final unpivoted cohort table with the chosen measure

  are wrapped in a "select *" since this is 
  requested for feeding them into the pivot clause/function
*/ 


select * from 
(
with
-- (1) select all the distinct records and 
-- (2) define the (weekly) cohorts as well as the subsequent weeks 
--     (using end_week) for each cohort
distinct_users as 
(
  select 
    distinct user_pseudo_id,
    date_trunc(subscription_start, WEEK) as cohort,
    date_trunc(subscription_end, WEEK) as end_week,
  from 
    `turing_data_analytics.subscriptions`
  -- only consider the period of 6 weeks ending on 2021-02-07
  where date_diff('2021-02-07', subscription_start, WEEK) <= 6
  order by cohort
),

-- first-week subscriptions for each cohort
first_week_subscriptions as (
  select
    max(cohort),
    cohort, 
    count(*) as n_first_week,
  from distinct_users
  group by cohort
),

-- n_churns for each week for each cohort
churns_by_week as (
  select
    cohort,
    end_week,
    countif(end_week is not null) as n_churns 
  from distinct_users
  group by
    cohort, end_week
  order by cohort, end_week -- not necessary but useful for in intermediate check
),

-- (1) join # of subscribers and n_churns for each cohort and each subsequent week
-- (2) add elapsed weeks from week_0 for each cohort
-- (3) add the cumulative sum of churns (which will be used to calculate retention)
joint_cohort_churns_table as
(
  select
    fw.cohort, fw.n_first_week, ch.n_churns,  
    -- number of elapsed weeks since the first week, including week_0 (hence the -1)
    -- NB: this could be obtained also in the previous CTE with `date_diff(end_week, cohort, WEEK) as cohort_week_date_diff`
    rank() over (partition by ch.cohort order by ch.end_week) -1  as cohort_week,
    -- cumulative sum of churns
    sum(ch.n_churns) over (partition by fw.cohort order by fw.cohort, ch.end_week) as cumsum_churns   
  from
    first_week_subscriptions fw join churns_by_week ch 
      on fw.cohort = ch.cohort
  order by 
    fw.cohort, ch.end_week
)

-- unpivoted table containing retention XOR retention rate
select 
  cohort, n_first_week, cohort_week,

  /* SELECT ONLY ONE OF EITHER `RETENTION` OR `RETENTION RATE` BELOW */
  n_first_week - cumsum_churns as measure, -- RETENTION
  -- round((n_first_week - cumsum_churns) / n_first_week, 3) as measure, -- RETENTION RATE

from
  joint_cohort_churns_table

) -- end of select * for pivot

-- pivot the calculated cohort metric into a standard cohort table view 
pivot
(
  sum(measure) as w
  for cohort_week in (0,1,2,3,4,5,6)
)
order by cohort
;



-- /* In the last week, it looks like there are no churns. It's better to check*/
-- select
--   count(subscription_start) as n_subscriptions,
--   count(subscription_end) as n_churns,
-- from 
--   `turing_data_analytics.subscriptions`
-- where 
--   subscription_start >= '2021-01-31'
-- ;
```
