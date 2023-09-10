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

-- EOF