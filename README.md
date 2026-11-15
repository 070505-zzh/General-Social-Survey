# Social Connection and Well-Being in the GSS, 1972–2024

A weighted descriptive analysis of the General Social Survey (GSS): friendship, happiness, sociability, social mobility and trust across survey years and age groups. The project uses **SQL** (SQLite) for summaries and **R** for survey-weighted estimates, logistic regression and visualization.

**Read first:** [`report/report.md`](report/report.md) (2-page summary) · `output/GSS_Analysis.html` (full analysis; download and open in a browser).

## Key findings
- **Happiness was stable for decades, then dropped in 2021:** 30.3% "very happy" in 1972 and 31.5% in 2018, but 19.4% in 2021 and 23.4% in 2024 (weighted). The drop coincides with COVID-19 and the switch to web/multimode interviews.
- **Trust has declined for decades:** 46.6% (1972) → 33.8% (2018) → 24.8% (2024). Recent trust data are mostly from in-person interviews.
- **Younger adults socialize more but are less happy and less trusting.** These age gaps hold after controlling for survey period (weighted logistic regression).

## Methods
- **SQL (SQLite):** `GROUP BY` summaries, `CASE WHEN` pivots, CTEs, `UNION ALL` reshaping, and `LAG()` / `SUM() OVER` window functions (`sql/queries.sql`).
- **Survey weights:** `WTSSPS` with `VPSU`/`VSTRAT` design (R `survey` package); 95% confidence intervals.
- **Models:** weighted logistic regression (`svyglm`) of "very happy" and "can trust" on age group and survey period, plus a survey-mode check for 2022–2024.
- **Validation:** unweighted results reproduce my earlier version of this analysis exactly.

## Folder structure
```
├── README.md
├── GSS_Analysis.Rmd          # full narrative analysis -> output/GSS_Analysis.html
├── R/
│   ├── 01_prepare_data.R     # load GSS, clean, build indicators, write SQLite
│   ├── 02_sql_summaries.R    # run sql/queries.sql, save CSVs
│   └── 03_analysis.R         # weighted estimates, mode check, regressions, figures
├── sql/queries.sql           # all SQL summaries
├── output/
│   ├── GSS_Analysis.html
│   ├── figures/              # 7 charts
│   └── *.csv                 # SQL and weighted result tables
└── report/report.md          # 2-page summary for non-technical readers
```

## Reproduce
Data are not included in the repo (the GSS file is large). Use one of these options:
1. Download `GSS_stata.zip` from [gss.norc.org](https://gss.norc.org/get-the-data/stata) and unzip it to `data/GSS_stata/`, **or**
2. Install the `gssr` package: `remotes::install_github("kjhealy/gssr")`.

Then run:
```bash
Rscript R/01_prepare_data.R
Rscript R/02_sql_summaries.R
Rscript R/03_analysis.R        # takes a few minutes (survey-weighted estimates)
Rscript -e 'rmarkdown::render("GSS_Analysis.Rmd", output_dir = "output")'
```
Required R packages: `dplyr`, `tidyr`, `haven`, `DBI`, `RSQLite`, `survey`, `ggplot2`, `scales`, `rmarkdown`, `knitr`.

## Source
Davern, M., Bautista, R., Freese, J., Herd, P., & Morgan, S. L. *General Social Survey 1972–2024* [Data set]. NORC at the University of Chicago.
