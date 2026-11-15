-- =============================================================================
-- queries.sql
-- Unweighted descriptive summaries of the GSS extract (SQLite dialect).
-- R/02_sql_summaries.R runs each statement and saves the result to output/.
-- Statements are separated by semicolons. Weighted estimates are done in R
-- with the survey package (see R/03_analysis.R).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. overall_summary: valid n, mean, min and max of each item.
--    UNION ALL stacks one row per variable into one table.
-- -----------------------------------------------------------------------------
SELECT 'HAPPY'    AS variable, '1 = very happy ... 3 = not too happy'  AS scale,
       COUNT(happy) AS valid_n, ROUND(AVG(happy), 2) AS mean, MIN(happy) AS min, MAX(happy) AS max FROM gss
UNION ALL
SELECT 'SOCFREND', '1 = almost daily ... 7 = never',
       COUNT(socfrend), ROUND(AVG(socfrend), 2), MIN(socfrend), MAX(socfrend) FROM gss
UNION ALL
SELECT 'SOCBAR', '1 = almost daily ... 7 = never',
       COUNT(socbar), ROUND(AVG(socbar), 2), MIN(socbar), MAX(socbar) FROM gss
UNION ALL
SELECT 'PARSOL', '1 = much better ... 5 = much worse',
       COUNT(parsol), ROUND(AVG(parsol), 2), MIN(parsol), MAX(parsol) FROM gss
UNION ALL
SELECT 'TRUST', '1 = can trust, 2 = cannot be too careful, 3 = depends',
       COUNT(trust), ROUND(AVG(trust), 2), MIN(trust), MAX(trust) FROM gss;


-- -----------------------------------------------------------------------------
-- 2. response_distribution: count and percent of every response category.
--    A CTE reshapes the five columns into long format, then a window function
--    computes each category's share within its variable.
-- -----------------------------------------------------------------------------
WITH long AS (
    SELECT 'HAPPY'    AS variable, happy    AS response FROM gss WHERE happy    IS NOT NULL
    UNION ALL SELECT 'SOCFREND', socfrend FROM gss WHERE socfrend IS NOT NULL
    UNION ALL SELECT 'SOCBAR',   socbar   FROM gss WHERE socbar   IS NOT NULL
    UNION ALL SELECT 'PARSOL',   parsol   FROM gss WHERE parsol   IS NOT NULL
    UNION ALL SELECT 'TRUST',    trust    FROM gss WHERE trust    IS NOT NULL
)
SELECT variable,
       CAST(response AS INTEGER) AS response,
       COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY variable), 1) AS pct
FROM long
GROUP BY variable, response
ORDER BY variable, response;


-- -----------------------------------------------------------------------------
-- 3. by_year: unweighted percentages for each survey year.
--    AVG() of a 0/1 column = proportion. AVG ignores NULLs, so years when a
--    question was not asked come out as NULL, not zero.
-- -----------------------------------------------------------------------------
SELECT year,
       COUNT(*)                                  AS respondents,
       COUNT(happy)                              AS happy_n,
       ROUND(100.0 * AVG(very_happy), 1)          AS pct_very_happy,
       COUNT(trust)                              AS trust_n,
       ROUND(100.0 * AVG(people_trusted), 1)      AS pct_trust,
       COUNT(socfrend)                           AS socfrend_n,
       ROUND(100.0 * AVG(friends_weekly), 1)      AS pct_friends_weekly,
       ROUND(AVG(socbar), 2)                      AS mean_socbar,
       COUNT(parsol)                             AS parsol_n,
       ROUND(100.0 * AVG(better_than_parents), 1) AS pct_better_than_parents
FROM gss
GROUP BY year
ORDER BY year;


-- -----------------------------------------------------------------------------
-- 4. by_age_group: unweighted summaries for each age group.
-- -----------------------------------------------------------------------------
SELECT age_group,
       COUNT(*)                                  AS respondents,
       ROUND(100.0 * AVG(very_happy), 1)          AS pct_very_happy,
       ROUND(100.0 * AVG(people_trusted), 1)      AS pct_trust,
       ROUND(AVG(socfrend), 2)                    AS mean_socfrend,
       ROUND(100.0 * AVG(friends_weekly), 1)      AS pct_friends_weekly,
       ROUND(AVG(socbar), 2)                      AS mean_socbar,
       ROUND(100.0 * AVG(better_than_parents), 1) AS pct_better_than_parents
FROM gss
WHERE age_group IS NOT NULL
GROUP BY age_group
ORDER BY age_group;


-- -----------------------------------------------------------------------------
-- 5. happy_year_by_age: percent "very happy" by year x age group, pivoted so
--    each age group is a column (conditional aggregation with CASE WHEN).
-- -----------------------------------------------------------------------------
SELECT year,
       ROUND(100.0 * AVG(CASE WHEN age_group = '18-24' THEN very_happy END), 1) AS age_18_24,
       ROUND(100.0 * AVG(CASE WHEN age_group = '25-34' THEN very_happy END), 1) AS age_25_34,
       ROUND(100.0 * AVG(CASE WHEN age_group = '35-44' THEN very_happy END), 1) AS age_35_44,
       ROUND(100.0 * AVG(CASE WHEN age_group = '45-59' THEN very_happy END), 1) AS age_45_59,
       ROUND(100.0 * AVG(CASE WHEN age_group = '60+'   THEN very_happy END), 1) AS age_60_plus
FROM gss
GROUP BY year
ORDER BY year;


-- -----------------------------------------------------------------------------
-- 6. change_by_decade: compare each period with the one before it using LAG().
-- -----------------------------------------------------------------------------
WITH by_period AS (
    SELECT period,
           MIN(year)                             AS first_year,
           ROUND(100.0 * AVG(very_happy), 1)     AS pct_very_happy,
           ROUND(100.0 * AVG(people_trusted), 1) AS pct_trust
    FROM gss
    GROUP BY period
)
SELECT period,
       pct_very_happy,
       ROUND(pct_very_happy - LAG(pct_very_happy) OVER (ORDER BY first_year), 1) AS change_very_happy,
       pct_trust,
       ROUND(pct_trust - LAG(pct_trust) OVER (ORDER BY first_year), 1)           AS change_trust
FROM by_period
ORDER BY first_year;


-- -----------------------------------------------------------------------------
-- 7. mode_2022_2024: responses by interview mode in 2022 and 2024, the years
--    when in-person, phone and web interviews were all used.
-- -----------------------------------------------------------------------------
SELECT mode_label,
       COUNT(*)                                  AS respondents,
       ROUND(100.0 * AVG(very_happy), 1)          AS pct_very_happy,
       ROUND(100.0 * AVG(people_trusted), 1)      AS pct_trust,
       ROUND(100.0 * AVG(friends_weekly), 1)      AS pct_friends_weekly,
       ROUND(AVG(age), 1)                         AS mean_age
FROM gss
WHERE year IN (2022, 2024)
  AND mode_label IS NOT NULL
GROUP BY mode_label
ORDER BY respondents DESC;
