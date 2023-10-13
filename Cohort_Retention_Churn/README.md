# Cohort retention and churn in SQL
_How to write a readable and adaptable query to calculate it in BigQuery SQL_


## Motivation

The main idea behind the calculation of cohort retention/churn is very simple. For instance, having defined a cohort of users as those who subscribe to a service/website in a given week, we would like to count how many are still subscribed in the following weeks (retention) and how many unsubscribe (churn). 

Calculating this metric for different cohorts (e.g. users subscribing in later weeks) can inform about the effect of different events - e.g. marketing campaigns or viral posts - onto our business.

**Despite its simplicity, an SQL query to calculate cohort retention/churn can become pretty complex and rigid**. This has disadvantages in terms of its maintainance and adaptability to different choices of _ad hoc_ analysis.

In the following I would like to show how to build a query which is (IMHO) easy to read and pretty adaptable to changes.

## Case study

Suppose you have a dataset like the following:

| user_pseudo_id        | subscription_start | subscription_end |
|-----------------------|--------------------|------------------|
| 83467479.3712028999   | 2020-11-01         | null             |
| 55666112.2535837096   | 2020-11-01         | null             |
| 3567303.5078176443    | 2020-11-02         | 2020-12-03       |
| 6417380.3726181994    | 2020-11-02         | null             |
| 8081585156.0442050150 | 2020-11-02         | null             |
| 1940972.5089265946    | 2020-11-03         | null             |
| 63964412.8050390474   | 2020-11-04         | null             |
| 91108794.8711815727   | 2020-11-04         | null             |
| 1526801.0560015811    | 2020-11-04         | 2020-11-05       |
| 17212306.7915035909   | 2020-11-06         | null             |

You would like to calculate user retention for the 6 weeks ending on 2021-02-07.

The final calculation should be displayed in the familiar triangular form

![](cohort_retention_table.jpg)


## Designing the query

The query can be articulated in 4 steps (plus one preliminary transformation):

0. If the cohort-level is defined by a week, truncate the `subscription_start` date at the week level to define the cohorts.

1. Then **calculate the size of each cohort** by counting the unique values into the truncated `subscription_start` and store it into a CTE.

2. In another CTE we will store the churns per week in each cohort. **Crucially, the number of churns is just the count of the non-null elements in the `subscription_end` column**, again after having truncated this value at the week level.

3. At this point, we can simply calculate the **cumulative sum of churn across weeks** using a window function. 

4. Finally, we **subtract the cumulative sum of churns per cohort/week from the cohort size to get the retention** (or retention rate).

I will show these passages separately below. The final complete query is at the end of the page


## 0. Define the cohorts

Assuming that we are interested in cohorts defined at the week level:

```sql
with
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
```

## 1. Calculate the size of each cohort

```sql

-- first-week subscriptions (cohort size) for each cohort
first_week_subscriptions as (
  select
    cohort, 
    count(*) as n_first_week,
  from distinct_users
  group by cohort
)
select * from first_week_subscriptions
```
Output:

| cohort     | n_first_week |
|------------|--------------|
| 2020-12-27 | 17059        |
| 2021-01-03 | 23291        |
| 2021-01-10 | 21799        |
| 2021-01-17 | 21073        |
| 2021-01-24 | 19998        |
| 2021-01-31 | 2255         |


## 2. Calculate number of churns for each following week in each cohort

This is the crucial passage. Instead of using multiple complex `SUM...CASE...WHEN` logics, which can be difficult to read and prone to errors, we realize that **the number of churns is just the number of non-null elements in the `end_week` column once we group them by both `cohort` and `end_week`**.

We also calculate the number of weeks elapsed from the first one for each cohort. This will be useful to pivot the final table to get the expected triangular form. We add 1 to represent the number of customers churning during the first week.

```sql
-- n_churns for each week for each cohort
churns_by_week as (
  select
    cohort,
    end_week,
    date_diff(end_week, cohort, WEEK) + 1 as elapsed_weeks,
    countif(end_week is not null) as n_churns,
  from distinct_users
  group by
    cohort, end_week
  order by cohort, end_week
)
```
By selecting * from all the previous CTEs, we get:

<details>
<summary>Toggle output</summary>

| cohort     | end_week   | elapsed_weeks | n_churns |
|------------|------------|---------------|----------|
| 2020-12-27 |            |               |          |
| 2020-12-27 | 2020-12-27 | 1             | 533      |
| 2020-12-27 | 2021-01-03 | 2             | 390      |
| 2020-12-27 | 2021-01-10 | 3             | 169      |
| 2020-12-27 | 2021-01-17 | 4             | 98       |
| 2020-12-27 | 2021-01-24 | 5             | 95       |
| 2020-12-27 | 2021-01-31 | 6             | 4        |
| 2021-01-03 |            |               |          |
| 2021-01-03 | 2021-01-03 | 1             | 872      |
| 2021-01-03 | 2021-01-10 | 2             | 671      |
| 2021-01-03 | 2021-01-17 | 3             | 262      |
| 2021-01-03 | 2021-01-24 | 4             | 170      |
| 2021-01-03 | 2021-01-31 | 5             | 13       |
| 2021-01-10 |            |               |          |
| 2021-01-10 | 2021-01-10 | 1             | 867      |
| 2021-01-10 | 2021-01-17 | 2             | 683      |
| 2021-01-10 | 2021-01-24 | 3             | 258      |
| 2021-01-10 | 2021-01-31 | 4             | 16       |
| 2021-01-17 |            |               |          |
| 2021-01-17 | 2021-01-17 | 1             | 945      |
| 2021-01-17 | 2021-01-24 | 2             | 824      |
| 2021-01-17 | 2021-01-31 | 3             | 34       |
| 2021-01-24 |            |               |          |
| 2021-01-24 | 2021-01-24 | 1             | 1040     |
| 2021-01-24 | 2021-01-31 | 2             | 196      |
| 2021-01-31 |            |               |          |

</details>
<br>

## 3. Join cohort size and n_churns
Now we can join the first two table on the common `cohort` column. 

We also calculate the cumulative sum of churns for each cohort. By subtracting this quantity from the cohort size, we will obtain the amount of retentions (in step 4.)

```sql
-- join cohort size (n_first_week) and n_churns per week per cohort
joint_cohort_churns_table as
(
  select
    fw.cohort,
    fw.n_first_week, 
    ch.elapsed_weeks,
    ch.n_churns,
    -- calculate the cumulative sum of churns over subsequent weeks (later used to calculate retention)
    sum(ch.n_churns) over (partition by ch.cohort order by ch.end_week) as cumsum_churns
  from first_week_subscriptions fw join churns_by_week ch 
    on fw.cohort = ch.cohort
)
```

## 4. Calculate retention values
At this point we have all the quantities to calculate the elements which will go into the retention table. Of course we can write the logic to calculate additional metrics - typically retention or churn rate 

```sql
-- calculate the final measure of retention and churn
select 
  cohort, 
  n_first_week, 
  case when elapsed_weeks IS NULL then 0 else elapsed_weeks end as elapsed_weeks, 
  n_churns,
  n_first_week - cumsum_churns as n_retention
from joint_cohort_churns_table
```

<details>
<summary>Toggle output</summary>

| cohort     | n_first_week | elapsed_weeks | n_churns | n_retention |
|------------|--------------|---------------|----------|-------------|
| 2020-12-27 | 17059        | 0             | 0        | 17059       |
| 2020-12-27 | 17059        | 1             | 533      | 16526       |
| 2020-12-27 | 17059        | 2             | 390      | 16136       |
| 2020-12-27 | 17059        | 3             | 169      | 15967       |
| 2020-12-27 | 17059        | 4             | 98       | 15869       |
| 2020-12-27 | 17059        | 5             | 95       | 15774       |
| 2020-12-27 | 17059        | 6             | 4        | 15770       |
| 2021-01-03 | 23291        | 0             | 0        | 23291       |
| 2021-01-03 | 23291        | 1             | 872      | 22419       |
| 2021-01-03 | 23291        | 2             | 671      | 21748       |
| 2021-01-03 | 23291        | 3             | 262      | 21486       |
| 2021-01-03 | 23291        | 4             | 170      | 21316       |
| 2021-01-03 | 23291        | 5             | 13       | 21303       |
| 2021-01-10 | 21799        | 0             | 0        | 21799       |
| 2021-01-10 | 21799        | 1             | 867      | 20932       |
| 2021-01-10 | 21799        | 2             | 683      | 20249       |
| 2021-01-10 | 21799        | 3             | 258      | 19991       |
| 2021-01-10 | 21799        | 4             | 16       | 19975       |
| 2021-01-17 | 21073        | 0             | 0        | 21073       |
| 2021-01-17 | 21073        | 1             | 945      | 20128       |
| 2021-01-17 | 21073        | 2             | 824      | 19304       |
| 2021-01-17 | 21073        | 3             | 34       | 19270       |
| 2021-01-24 | 19998        | 0             | 0        | 19998       |
| 2021-01-24 | 19998        | 1             | 1040     | 18958       |
| 2021-01-24 | 19998        | 2             | 196      | 18762       |
| 2021-01-31 | 2255         | 0             | 0        | 2255        |

</details>
<br>

These values can then be copied in Google Sheets / Excel, where we can generate the triangular table by simply placing `cohort` in the rows, `elapsed_weeks` in the columns, and the `n_retention` as a cell value.

## Final considerations
Of course the initial dataset can have a different form, however eventually we want to get to a table that looks like the one proposed at the beginning, and from there we can easily calculate the cohort retention values.

This formulation is quite long. Much shorter formulations can be written using complex logic. It is always great to have a concise logic, however when the option is between concise or readable, I prefer the second option.

The final table still needs to be imported in a spreadsheet for pivoting. Indeed it is possible to carry out the pivoting also in BigQuery directly. This can be obtained by enclosing the whole query in a select * and afterward using the `pivot` function.

I find it potentially cumbersome for the syntax, especially if we want to modify the number of weeks to run the cohort analysis on. Anyway, this is how the syntax and the output would look like:

```sql
select * from
(
    -- the whole query goes here
    -- make sure you select only ONE metric (e.g. either n_churns or n_retention)
)
pivot
(
  sum(n_retention) as w
  for elapsed_weeks in (0,1,2,3,4,5,6)
)
order by cohort
```

Output for `n_retention`:
| cohort     | n_first_week | w_0   | w_1   | w_2   | w_3   | w_4   | w_5   | w_6   |
|------------|--------------|-------|-------|-------|-------|-------|-------|-------|
| 2020-12-27 | 17059        | 17059 | 16526 | 16136 | 15967 | 15869 | 15774 | 15770 |
| 2021-01-03 | 23291        | 23291 | 22419 | 21748 | 21486 | 21316 | 21303 |       |
| 2021-01-10 | 21799        | 21799 | 20932 | 20249 | 19991 | 19975 |       |       |
| 2021-01-17 | 21073        | 21073 | 20128 | 19304 | 19270 |       |       |       |
| 2021-01-24 | 19998        | 19998 | 18958 | 18762 |       |       |       |       |
| 2021-01-31 | 2255         | 2255  |       |       |       |       |       |       |


Output for `n_churns`:
| cohort     | n_first_week | w_0 | w_1  | w_2 | w_3 | w_4 | w_5 | w_6 |
|------------|--------------|-----|------|-----|-----|-----|-----|-----|
| 2020-12-27 | 17059        | 0   | 533  | 390 | 169 | 98  | 95  | 4   |
| 2021-01-03 | 23291        | 0   | 872  | 671 | 262 | 170 | 13  |     |
| 2021-01-10 | 21799        | 0   | 867  | 683 | 258 | 16  |     |     |
| 2021-01-17 | 21073        | 0   | 945  | 824 | 34  |     |     |     |
| 2021-01-24 | 19998        | 0   | 1040 | 196 |     |     |     |     |
| 2021-01-31 | 2255         | 0   |      |     |     |     |     |     |




## Full query

```sql
with
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
    date_diff(end_week, cohort, WEEK) + 1 as elapsed_weeks,
    countif(end_week is not null) as n_churns,
  from distinct_users
  group by
    cohort, end_week
  order by cohort, end_week
),

-- join cohort size (n_first_week) and n_churns per week per cohort
joint_cohort_churns_table as
(
  select
    fw.cohort,
    fw.n_first_week, 
    ch.elapsed_weeks,
    ch.n_churns,
    -- calculate the cumulative sum of churns over subsequent weeks (later used to calculate retention)
    sum(ch.n_churns) over (partition by ch.cohort order by ch.end_week) as cumsum_churns
  from first_week_subscriptions fw join churns_by_week ch on fw.cohort = ch.cohort
)

-- calculate the final measure of retention and churn
select 
  cohort, 
  n_first_week, 
  case when elapsed_weeks IS NULL then 0 else elapsed_weeks end as elapsed_weeks, 
  n_churns,
  n_first_week - cumsum_churns as n_retention
from joint_cohort_churns_table
```


# Bonus: how to make the same in R
Using `dplyr` and `lubridate`. 

NB: unfortunately I cannot provide the data. The format of the table is the one I provided at the beginning.

<details>
<summary>R script to calculate retention table</summary>

```R
library(tidyverse)
library(lubridate)

df <- read_csv("data_cohort.csv")


# calculate the number of churns per week and per cohort
n_churns <- df %>%
 mutate(start_week = floor_date(subscription_start, unit = "week") ) %>% 
 mutate(end_week = floor_date(subscription_end, unit = "week") ) %>%
 filter(!is.na(end_week)) %>%
 count(start_week, end_week) %>%
 rename(n_churns = n) %>% 
 arrange(start_week, end_week) %>% 
 group_by(start_week) %>%
 mutate(elapsed_weeks = rank(end_week))


# subscriptions per week
n_users_each_week <- df %>%
 mutate(start_week = floor_date(subscription_start, unit = "week") ) %>%
 select(start_week) %>% 
 group_by(start_week) %>% 
 summarise(total_week_subscriptions = n())


# join and calculate churn/retention
# R = retention
# RR = retention_rate
# CR = churn rate
to_be_pivoted <- n_users_each_week %>% 
 inner_join(n_churns, by = "start_week") %>% 
 mutate(R = total_week_subscriptions - n_churns) %>% 
 mutate(RR = (total_week_subscriptions - n_churns) / total_week_subscriptions) %>% 
 mutate(CR = 1 - RR)


# pivot to the standard view
final_table <- to_be_pivoted %>% 
 select(start_week, elapsed_weeks, RR) %>% 
 pivot_wider(names_from = elapsed_weeks, values_from = RR)

View(final_table)

```

</details>