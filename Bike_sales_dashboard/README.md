## Salespersons' performance 


### Quick Links
- [Preliminary EDA](https://docs.google.com/spreadsheets/d/1I0pLfQLiyjO6UDb-T-ox29nBXqUYynFj7NEGnPcN8Rc/edit?usp=sharing) (Google Sheets)
- [Dashboard for exploration](https://public.tableau.com/app/profile/leonardo.cerliani/viz/SP_Geo_v2/SalesPersonsPerformanceperUSTerritory)
- [Dashboard story with key insights](https://public.tableau.com/app/profile/leonardo.cerliani/viz/SP_Geo_v2_Story/SomeKeyInsights)
- [2 minutes presentation for Executive Leadership](2min_presentation.pdf)
- [10 minutes presentation for Sales Department](10min_presentation_Sales.pdf)
- [SQL query](#sql-query) to gather the data for preliminary analyses and for dashboards
- [Background research](#backgroud-research) on US bike friendly cities and bike commuters to work in US

### Background
[Adventureworks](https://learn.microsoft.com/en-us/sql/samples/adventureworks-install-configure?view=sql-server-ver16&tabs=ssms) is a fictitious company selling bikes and accessories. 

After conducting a 360º exploration of various aspects of this dataset, I decided to focus on investigating the reasons behind the variability in the performance of different salespersons, above and beyond the total amount of sales - e.g. career, experience, geographical location.

### Main preliminary results
- Volume of sales and Growth over quarters is slower in Central and Eastern US Territories

- We investigated to what extent this can be related to the the distribution of Salespersons across US regions (NorthWest, SouthWest, Central, NorthEast, SouthEast)

- We suggest that Western regions have an excess of SPs with growing trend, which could lead to market saturation in the near future.

- Instead, refocusing promising SPs in the Central and especially East regions could benefit their portfolio growth as well as the growth of the company market in these regions

- During the process we created a dashboard in Tableau that can also be provided to the Management and Sales department for further exploration and gaining additional insights

[Open the dashboard for exploration](https://public.tableau.com/app/profile/leonardo.cerliani/viz/SP_Geo_v2/SalesPersonsPerformanceperUSTerritory)
![](dashboard_exploration_snapshot.png)


### Key Insights

Using this dashboard, one can derive many insights about how to improve sales in the Central and East US territories - as far as SPs’ sales are concerned.

For instance: 

- In the East there are much less SPs than on the West coast - and some of them are operating also in the West. Conversely, some SP are exclusively operating in the West. This is one reason that can explain the lower performance in the East.

- Some of the highest SPs performance is actually declining at the regional level - although it might look like it is increasing across regions.

- On the other hand, some SP are on a steady increase, but their activity is either too spread across regions or deployed in regions which are already saturated with SPs and doing very well while they could help improve the sales in Central and East.

- Also, some top SPs receive high commissions despite their stalled or declining performance while SP receive no commissions despite their increasing performance.

[Open the dashboard with key insights](https://public.tableau.com/app/profile/leonardo.cerliani/viz/SP_Geo_v2_Story/SomeKeyInsights)
![](dashboard_story_snapshot.png)


### SQL query
```sql
/* 
  Sales data with SalesOrderID as PK
  containing info about OrderDate, Online/Offline (i.e. SP operated),
  TotalDue, CustomerID with TerritoryID
  This is useful to break down sales per SP in order to breakdown
  by Volume, # orders, # clients for each SP
*/
select
  distinct
  soh.SalesOrderID, 
  date(soh.OrderDate) as OrderDate, 
  soh.CustomerID, 
  soh.SalesPersonID, 
  soh.TerritoryID, 
  soh.TotalDue,
  st.CountryRegionCode,
  st.Name as Territory,
  -- addr.StateProvinceID,
  sp.StateProvinceCode as State_Code,
  sp.Name as State
from
  `adwentureworks_db.salesorderheader` soh
  join `adwentureworks_db.salesterritory` st on soh.TerritoryID = st.TerritoryID
  join `adwentureworks_db.address` addr on soh.BillToAddressID = addr.AddressID
  join `adwentureworks_db.stateprovince` sp on addr.StateProvinceID = sp.StateProvinceID
where sp.CountryRegionCode = "US"
;

```

### Background research

#### Data about US bike friendly cities
[The 50 most bike-friendly cities in US, ranked](https://anytimeestimate.com/research/most-bike-friendly-cities-us-2022/)

```R
# Load the necessary packages
library(rvest)
library(tidyverse)

# Specify the URL of the page with the table
url <- "https://anytimeestimate.com/research/most-bike-friendly-cities-us-2022/"

# Use rvest to scrape the table
page <- read_html(url)
table_html <- page %>%
  html_nodes("table") %>%
  .[[3]] %>%
  html_table(header = TRUE)

df <- page %>%
  html_nodes("table") %>%
  .[[3]] %>%
  html_table(header = TRUE) %>% 
  as.tibble() %>% 
  filter(!grepl("Nat",City), !grepl("criteria",City)) %>%  # filter out first and last row
  mutate(`% Workers Commuting by Bicycle` = as.numeric(gsub("%", "", `% Workers Commuting by Bicycle`))) %>% 
  mutate_at(vars(starts_with("Bike") | starts_with("Days")), funs(as.numeric)) %>%  # convert to numeric
  separate(City, c("City", "State Code"), sep = ", ")


df_50_most_friendly_bike_cities <- df

write_csv(df_50_most_friendly_bike_cities, "50_most_friendly_bike_cities_US.csv")
```

#### Data about number of workers commuting with bike in US cities

[Percent of people biking to work in US cities with more than 65K people](https://www.governing.com/archive/bike-to-work-map-us-cities-census-data.html#data)

```R
library(rvest)

url <- "https://www.governing.com/archive/bike-to-work-map-us-cities-census-data.html#data"

# Read in the HTML from the URL
html <- read_html(url)

# Find the table and extract its contents
table_data <- html %>%
  html_nodes("table") %>%
  html_table(header = TRUE)

df <- table_data[[1]]

# Use the first row for column names
colnames(df) <- as.character(df[1, ])

# Remove the first row, which is now redundant
df <- df[-1, ] %>% 
  repair_names()

# Separate City and State
df <- df %>% 
  separate(City, c("City", "State"), sep = ", ")

df_percent_people_biking_US_cities <- df


View(df_percent_people_biking_US_cities)
```

#### Combined dataset
```R
df_bike_friendly_cities <- df_percent_people_biking_US_cities %>% 
  select(-starts_with("Margin")) %>% 
  left_join(df_50_most_friendly_bike_cities, by = "City")

write_csv(df_bike_friendly_cities, "50_most_friendly_bike_cities_US.csv")

View(df_bike_friendly_cities)
```

#### Other sources

https://enviroatlas.epa.gov/enviroatlas/interactivemap/