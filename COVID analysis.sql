-- Chapter 1: Basic Exploration
-- 1.1 Explore the CountryProfile table
SELECT *
FROM CountryProfile
ORDER BY 2,3;

-- 1.2 Explore the DailyData table
SELECT *
FROM DailyData
ORDER BY 2,3;

-- 1.3 Explore the VaccinationData table
SELECT *
FROM VaccinationData
ORDER BY 2,3;

-- Chapter 2: Global Insights
-- 2.1 Sum of daily new cases and deaths worldwide
SELECT date, 
       SUM(new_cases) AS GlobalNewCases, 
       SUM(new_deaths) AS GlobalNewDeaths 
FROM DailyData 
WHERE continent IS NOT NULL 
GROUP BY date 
ORDER BY date;

-- 2.2 Global sum of people vaccinated over time
SELECT date, SUM(CAST(people_vaccinated AS FLOAT)) AS TotalPeopleVaccinated 
FROM VaccinationData 
GROUP BY date 
ORDER BY date;

-- Chapter 3: Country-Level Overview
-- 3.1 Top 10 countries by total cases
SELECT TOP 10 location, MAX(CAST(total_cases AS INT)) AS TotalCases 
FROM DailyData 
WHERE continent IS NOT NULL
GROUP BY location 
ORDER BY TotalCases DESC;

-- 3.2 Top 10 countries by total deaths
SELECT TOP 10 location, MAX(CAST(total_deaths AS INT)) AS TotalDeaths 
FROM DailyData 
WHERE continent IS NOT NULL
GROUP BY location 
ORDER BY TotalDeaths DESC;

-- Chapter 4: In-depth Country Analysis
-- 4.1 COVID Case Fatality Rate by Country and Date
SELECT location, date, total_cases, total_deaths,
       ROUND((total_deaths/CAST(total_cases AS FLOAT))*100,2) AS death_percentage
FROM DailyData
WHERE continent IS NOT NULL 
ORDER BY 1,2;

-- 4.2 COVID Infection Rate by Country and Date
SELECT location, date, population, total_cases, 
       ROUND((total_cases/population)*100,2) AS infection_rate
FROM DailyData
WHERE continent IS NOT NULL
ORDER BY 1,2;

-- 4.3 Highest COVID Infection Rates by Country
SELECT location, population, MAX(total_cases) AS Highest_infection_count,
       ROUND(MAX(total_cases)/population*100,2) AS Highest_infection_rate
FROM DailyData
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY 4 DESC;

-- 4.4 Countries with the Highest COVID Death Rates
SELECT location,
       MAX(CAST(total_deaths AS INT)) AS Highest_deaths_count,
       ROUND(MAX(CAST(total_deaths AS INT)/population)*100,2) AS Highest_deaths_rate
FROM DailyData
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY 3 DESC;

-- Chapter 5: Correlation Analyses
-- 5.1 Correlation between GDP per capita and COVID Cases per Population
SELECT dd.location, cp.gdp_per_capita, 
       ROUND(MAX(dd.total_cases/dd.population),2) AS CasesPerPopulation
FROM DailyData dd
JOIN CountryProfile cp ON dd.location = cp.location 
WHERE cp.gdp_per_capita IS NOT NULL
GROUP BY dd.location, cp.gdp_per_capita
HAVING ROUND(MAX(dd.total_cases/dd.population),2) IS NOT NULL
ORDER BY cp.gdp_per_capita DESC;

-- 5.2 Correlation between HDI and COVID Death Percentage
SELECT dd.location, cp.human_development_index AS HDI,
       ROUND(SUM(CAST(total_deaths AS FLOAT))/SUM(CAST(total_cases AS FLOAT))* 100,2) AS death_percentage
FROM DailyData dd
JOIN CountryProfile cp ON dd.location = cp.location 
WHERE cp.human_development_index IS NOT NULL
GROUP BY dd.location, cp.human_development_index
ORDER BY cp.human_development_index;

-- Chapter 6: Vaccination Analysis
-- 6.1 Cumulative Vaccinations by Country and Date
WITH VaccPercentage_cte AS (
    SELECT dd.continent, dd.location, dd.date, dd.population, vd.new_vaccinations,
           SUM(CAST(vd.new_vaccinations AS FLOAT)) OVER (PARTITION BY dd.location ORDER BY dd.location, dd.date) AS rolling_vaccinated_count
    FROM DailyData dd
    JOIN VaccinationData vd ON dd.date = vd.date AND dd.location = vd.location
    WHERE dd.continent IS NOT NULL
)

SELECT *, ROUND((rolling_vaccinated_count/population*100),2) AS rolling_vaccinated_rate
FROM VaccPercentage_cte
WHERE location LIKE '%isr%'
ORDER BY 2,3;

-- 6.2 Countries with the highest vaccination rates
CREATE VIEW HighVaccinationRate AS
SELECT Vd.location, 
       ROUND(MAX(people_fully_vaccinated)/dd.population*100,2) AS vaccination_rate
FROM VaccinationData Vd
JOIN DailyData Dd ON Vd.location = Dd.location AND Vd.date = Dd.date
WHERE Dd.continent IS NOT NULL
GROUP BY Vd.location, Dd.population;

SELECT * 
FROM HighVaccinationRate
ORDER BY vaccination_rate DESC;

-- Chapter 7: Time Series and Trends
-- 7.1 Day-to-Day Comparison of New Cases
WITH DayToDayDiff_cte AS (
    SELECT location, date, new_cases,
    LEAD(new_cases) OVER (PARTITION BY location ORDER BY date) AS NextDayNewCases
    FROM DailyData 
    WHERE continent IS NOT NULL
)

SELECT *,
       CASE 
           WHEN new_cases = 0 THEN 0 
           ELSE ROUND((NextDayNewCases/new_cases *100-100 ), 2)
       END AS PercentageDifference
FROM DayToDayDiff_cte
ORDER BY 1,2;

-- 7.2 Percentage of COVID Positive Tests by Country and Date
SELECT location, date, new_cases, new_tests,
       CASE 
           WHEN new_tests = 0 THEN NULL 
           ELSE ROUND((new_cases/new_tests*100),2) 
       END AS PositivePercentage
FROM DailyData 
WHERE new_tests IS NOT NULL AND continent IS NOT NULL AND location LIKE 'isr%'
ORDER BY 1,2;

-- 7.3 7-Day mooving Average of New COVID Cases
SELECT location, date, new_cases,
       ROUND(AVG(new_cases) OVER (PARTITION BY location ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),2) AS Running7DayAvg
FROM DailyData
WHERE continent IS NOT NULL
ORDER BY location, date;

-- 7.4 7-Day mooving Average of New COVID Deaths
SELECT location, date, new_deaths,
       ROUND(AVG(new_deaths) OVER (PARTITION BY location ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),2) AS Running7DayAvg
FROM DailyData
WHERE continent IS NOT NULL
ORDER BY location, date;

-- Chapter 8: Advanced Insights
-- 8.1 Time Span from First COVID Case to First Vaccination by Country
WITH FirstCaseDate_cte AS (
    SELECT location, MIN(date) as FirstCaseDate
    FROM DailyData
    WHERE total_cases > 0
    GROUP BY location
),
FirstVaccinationDate_cte AS (
    SELECT location, MIN(date) as FirstVaccinationDate
    FROM VaccinationData
    WHERE new_vaccinations > 0 and continent is not null
    GROUP BY location
)
SELECT fc.location, fc.FirstCaseDate, fv.FirstVaccinationDate,
       DATEDIFF(DAY, fc.FirstCaseDate, fv.FirstVaccinationDate) as DaysBetweenFirstCaseAndVaccination
FROM FirstCaseDate_cte fc
JOIN FirstVaccinationDate_cte fv ON fc.location = fv.location
ORDER BY 4;