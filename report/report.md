# Social Connection and Well-Being in the U.S., 1972–2024
**Weighted analysis of the General Social Survey (GSS)**
Zihe (Eric) Zhang

---

## Summary

Using 75,699 GSS respondents from 35 survey years, I examined happiness, friendship, sociability, social mobility and trust, and how they differ across survey years and age groups. Estimates use the GSS survey weights with 95% confidence intervals. Three results stand out:

1. **Happiness was stable for decades, then dropped in 2021.** The weighted share of adults saying they are "very happy" was 30.3% in 1972 and 31.5% in 2018, but 19.4% in 2021 and 23.4% in 2024. The drop appears in every age group and coincides with both COVID-19 and the GSS's switch to web and multimode interviewing.
2. **Trust has declined for decades.** The share saying "most people can be trusted" fell from 46.6% (1972) to 33.8% (2018) and 24.8% (2024). Recent trust data come almost entirely from in-person and phone interviews, so this decline is not explained by the switch to web interviews.
3. **Younger adults socialize more but are less happy and less trusting.** 47.0% of 18–24-year-olds spend an evening with friends at least weekly (vs. 13.0% of those 60+), yet they have the lowest shares of "very happy" (24.7% vs. 34.8% for 60+) and of trust (26.7% vs. 41.7% for 45–59).

## Data and approach

- **Data:** GSS 1972–2024 cumulative file (NORC). Variables: HAPPY, SOCFREND, SOCBAR, PARSOL and TRUST. Age groups: 18–24, 25–34, 35–44, 45–59 and 60+.
- **SQL:** the cleaned extract was loaded into SQLite. Year, age-group and period summaries were built with `GROUP BY`, `CASE WHEN` pivots, CTEs and the `LAG()` window function.
- **Survey weights:** the recommended `WTSSPS` weight with the clustered, stratified design (`survey` package in R).
- **Models:** weighted logistic regressions with age group and survey period as predictors.
- **Validation:** the unweighted numbers exactly reproduce my earlier analysis (for example, 30.3% → 20.8% "very happy").

## Key findings

| Indicator (weighted) | 18–24 | 25–34 | 35–44 | 45–59 | 60+ |
|---|---|---|---|---|---|
| Very happy | 24.7% | 30.4% | 31.1% | 31.6% | 34.8% |
| Most people can be trusted | 26.7% | 31.0% | 38.8% | 41.7% | 40.2% |
| Evenings with friends at least weekly | 47.0% | 26.9% | 18.1% | 14.5% | 13.0% |
| Better off than parents | 67.4% | 59.6% | 58.7% | 59.5% | 69.0% |

**Age vs. period (logistic regression).**
- Holding period constant, adults 60+ have 1.70 times the odds of being "very happy" compared with 18–24-year-olds.
- Holding period constant, 45–59-year-olds have 2.10 times the odds of trusting most people compared with 18–24-year-olds.
- For happiness, period effects are small until 2021–2024 (odds ratio 0.53 vs. the 1970s).
- For trust, the decline starts in the 1990s (odds ratio 0.69) and reaches 0.43 in 2021–2024.

**Survey mode (2022 and 2024).**
- Web/multimode respondents reported "very happy" less often than in-person respondents (22.7% vs. 26.3%).
- After adjusting for age and year, the odds ratio for web vs. in person is 0.80 (p = 0.03).
- Respondents chose their mode, so this is not a controlled comparison. Still, it means the post-2021 happiness drop should be interpreted with caution.

**Mobility.** Most adults in every age group feel better off than their parents did at the same age, with a U-shaped pattern: lowest for ages 35–44 and highest for the youngest and oldest groups.

## Why it matters

The project shows that headline trends can depend on **how** data are collected. Weighting, question coverage and changes in survey mode can all shift the numbers. Checking these factors is the same discipline needed when a business metric changes after a change in tracking or in the user mix.

## Limitations

- Age, period and birth cohort cannot be fully separated in repeated cross-sectional data.
- Pandemic and survey-mode effects overlap in 2021–2024.
- Some items were not asked every year (TRUST not in 2021; PARSOL only from 1994).
- Ordinal scales were simplified into yes/no indicators for the regressions.

## Next steps

- Add birth cohort to the models.
- Use ordinal regression to keep the full response scales.
- Compare with surveys that did not change mode in 2021.
