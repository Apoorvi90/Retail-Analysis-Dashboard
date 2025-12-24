CREATE DATABASE retail_analysis;
USE retail_analysis;

SELECT COUNT(*) FROM train_data;
SELECT * FROM features_data;

## CLEANING TRAIN DATA 
 
CREATE TABLE train_cleaned AS
SELECT * FROM train_data;

# MODIFY DATA TYPES
ALTER TABLE train_cleaned MODIFY Date DATE, MODIFY Store INT, MODIFY Dept INT, MODIFY Weekly_Sales Decimal(12,2);


# CHECKING NULL VALUES
SELECT Date FROM train_cleaned WHERE Date IS NULL;
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN Weekly_Sales IS NULL THEN 1 ELSE 0 END) AS missing_sales,
    SUM(CASE WHEN Store IS NULL THEN 1 ELSE 0 END) AS missing_store,
    SUM(CASE WHEN Dept IS NULL THEN 1 ELSE 0 END) AS missing_dept
FROM train_cleaned;
# Result:- NO NULL VALUES

# CHECKING DUPLICATE VALUES
SELECT
    Store, Dept, Date, COUNT(*) AS cnt
FROM train_cleaned
GROUP BY Store, Dept, Date
HAVING cnt > 1;
# Result:- No Duplicate values

# HANDLING INVALID/NEGATIVE SALES
SELECT *
FROM train_cleaned
WHERE Weekly_Sales < 0;

UPDATE train_cleaned AS tc
JOIN (SELECT Store, Dept, AVG(Weekly_Sales) AS Avg_Sales FROM train_cleaned WHERE Weekly_Sales >= 0 GROUP BY Store, Dept) AS t_avg
ON tc.Store=t_avg.Store AND tc.Dept=t_avg.Dept
SET tc.Weekly_Sales=t_avg.Avg_Sales
WHERE tc.Weekly_Sales < 0;

UPDATE train_cleaned SET Weekly_Sales=0 WHERE Weekly_Sales<0;

## CLEANING FEATURES DATA

CREATE TABLE features_cleaned AS
SELECT * FROM features_data;

# MODIFY DATA TYPES
ALTER TABLE features_cleaned MODIFY Store INT, MODIFY Date DATE, MODIFY Temperature DECIMAL(10,2), MODIFY Fuel_Price DECIMAL(10,2), MODIFY CPI DECIMAL(15,2);

UPDATE features_cleaned SET MarkDown1=COALESCE(MarkDown1,0),MarkDown2=COALESCE(MarkDown2,0),MarkDown3=COALESCE(MarkDown3,0),MarkDown4=COALESCE(MarkDown4,0),MarkDown5=COALESCE(MarkDown5,0);

ALTER TABLE features_cleaned ADD Total_Markdown DECIMAL(15,2);
UPDATE features_cleaned SET Total_Markdown=(MarkDown1+MarkDown2+MarkDown3+MarkDown4+MarkDown5);

# CHECKING NULL VALUES
SELECT Date FROM features_cleaned WHERE Date IS NULL;
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN Temperature IS NULL THEN 1 ELSE 0 END) AS missing_temp,
    SUM(CASE WHEN Fuel_Price IS NULL THEN 1 ELSE 0 END) AS missing_fp,
    SUM(CASE WHEN CPI IS NULL THEN 1 ELSE 0 END) AS missing_cpi,
    SUM(CASE WHEN IsHoliday IS NULL THEN 1 ELSE 0 END) AS missing_hol
FROM features_cleaned;
# Result:- Null values in CPI
# correcting null values in CPI
SELECT DISTINCT DATE,COUNT(*)  FROM features_cleaned WHERE CPI IS NULL GROUP BY DATE ORDER BY DATE ;

CREATE TEMPORARY TABLE cpi_fill AS
SELECT f1.Date,(SELECT f2.CPI FROM features_cleaned f2 WHERE f2.Date < f1.Date AND f2.CPI IS NOT NULL ORDER BY f2.Date DESC LIMIT 1) AS filled_cpi
FROM features_cleaned f1
WHERE f1.CPI IS NULL
GROUP BY f1.Date;

UPDATE features_cleaned f
JOIN cpi_fill c
  ON f.Date = c.Date
SET f.CPI = c.filled_cpi
WHERE f.CPI IS NULL;

# CHECKING DUPLICATE VALUES
SELECT
    Store, Date, COUNT(*) AS cnt
FROM FEATURES_cleaned
GROUP BY Store, Date
HAVING cnt > 1;
# Result:- No Duplicate values

# JOINING BOTH CLEANED DATA

CREATE TABLE retail_final AS
SELECT tc.Store,tc.Dept,tc.Date,tc.Weekly_Sales,fc.Temperature,fc.Fuel_Price,fc.CPI,fc.Total_Markdown,fc.IsHoliday FROM train_cleaned AS tc
LEFT JOIN features_cleaned AS fc
ON tc.Store=fc.Store AND tc.Date=fc.Date;

SELECT * FROM retail_final;

# KPIs
# 1. Overall Business KPI
SELECT COUNT(DISTINCT Store) AS Total_Stores,
       COUNT(DISTINCT Dept) AS Total_dept,
       ROUND(SUM(Weekly_Sales),2) AS Total_Sales,
       ROUND(AVG(Weekly_Sales),2) AS Avg_Weekly_Sales 
FROM retail_final ;

# 2. Store Performance KPI
SELECT Store,ROUND(SUM(Weekly_Sales),2) AS Total_Sales FROM retail_final GROUP BY Store ORDER BY Total_Sales DESC;  # Total sales by store
SELECT Store,ROUND(AVG(Weekly_Sales),2) AS Avg_Weekly_Sales FROM retail_final GROUP BY Store ORDER BY Avg_Weekly_Sales DESC;   # Average weekly sales by store

# 3. Department Performance KPI
SELECT Dept,ROUND(SUM(Weekly_Sales),2) AS Total_sales FROM retail_final GROUP BY Dept ORDER BY total_sales DESC;    # Total sales by department
SELECT Dept,ROUND(AVG(Weekly_Sales),2) AS Avg_Weekly_Sales FROM retail_final GROUP BY Dept ORDER BY Avg_Weekly_Sales DESC;   # Average weekly sales by department

# 4. Store × Department KPI
SELECT Store,Dept, ROUND(AVG(Weekly_Sales),2) AS Avg_Weekly_Sales FROM retail_final GROUP BY Store,Dept ORDER BY Avg_Weekly_Sales DESC;

# 5. Time-Based KPIs
SELECT YEAR(Date) AS Year,MONTH(Date) AS Month,ROUND(SUM(Weekly_Sales),2) AS Monthly_sales FROM retail_final GROUP BY Year,Month ORDER BY Year,Month;  # Monthly sales trend
SELECT YEAR(Date) AS Year,ROUND(SUM(Weekly_Sales),2) AS Yearly_sales FROM retail_final GROUP BY Year ORDER BY Year;   # Yearly sales trend

# 6. Holiday Impact KPI
SELECT IsHoliday,ROUND(SUM(Weekly_Sales),2) AS Total_sales,ROUND(AVG(Weekly_Sales),2) AS Avg_Weekly_Sales FROM retail_final GROUP BY IsHoliday;

# 7. External Factors KPI
SELECT ROUND(CPI,1) AS CPI,ROUND(AVG(Weekly_Sales),2) AS Avg_Weekly_Sales FROM retail_final GROUP BY CPI ORDER BY CPI;   # CPI impact
SELECT Fuel_Price,ROUND(AVG(Weekly_Sales),2) AS Avg_Weekly_Sales FROM retail_final GROUP BY Fuel_Price ORDER BY Fuel_Price;  # Fuel_Price impact

# 8. Promotion vs Non-Promotion Sales
SELECT
 CASE 
     WHEN Total_Markdown > 0 THEN "Promotion"
     ELSE "No Promotion"
 END AS Promo_Type,
 ROUND(SUM(Weekly_Sales),2) AS Total_sales,
 ROUND(AVG(Weekly_Sales),2) AS Avg_Weekly_Sales
FROM retail_final
GROUP BY Promo_Type; 

# 9. Validation KPI
SELECT YEAR(Date) AS Year,MONTH(Date) AS Month,ROUND(AVG(Weekly_Sales),2) AS Avg_Weekly_sales FROM retail_final WHERE Store = 1 AND Dept = 1 GROUP BY Year, Month ORDER BY Year, Month;
# Confirms my Excel findings using SQL

# 10. Inventory Turnover
SELECT Store,Dept,ROUND(SUM(Weekly_Sales)/AVG(Weekly_Sales),2) AS Inventory_Turnover FROM retail_final GROUP BY Store,Dept;

# 11. Reorder Point (Assuming lead time = 2 weeks)
SELECT Store,Dept,ROUND(AVG(Weekly_Sales)*2,2) AS Reorder_Point FROM retail_final GROUP BY Store,Dept;








