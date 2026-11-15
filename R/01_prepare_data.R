# =============================================================================
# 01_prepare_data.R
# Load the GSS 1972-2024 cumulative file, keep the variables used in this
# project, clean them, and write the extract to CSV and to a SQLite database.
#
# Data options (the script uses the first one it finds):
#   1. Official NORC Stata file:  data/GSS_stata/gss7224_r3a.dta
#      (download "GSS_stata.zip" from https://gss.norc.org/get-the-data/stata)
#   2. data/gss_all.rda           (the cumulative file shipped in the gssr package)
#   3. The installed gssr package: remotes::install_github("kjhealy/gssr")
# =============================================================================

library(dplyr)
library(haven)
library(DBI)
library(RSQLite)

vars <- c("year", "id", "age", "happy", "socfrend", "socbar", "parsol", "trust",
          "mode", "wtssps", "vpsu", "vstrat")

# ---- 1. Load the raw data ---------------------------------------------------
dta_path <- "data/GSS_stata/gss7224_r3a.dta"
rda_path <- "data/gss_all.rda"

if (file.exists(dta_path)) {
  gss_raw <- read_dta(dta_path, col_select = all_of(vars))
  source_note <- "NORC GSS 1972-2024 cumulative file (Stata)"
} else if (file.exists(rda_path)) {
  load(rda_path)                        # creates the object gss_all
  gss_raw <- gss_all[, vars]
  rm(gss_all)
  source_note <- "GSS 1972-2024 cumulative file via the gssr package (data/gss_all.rda)"
} else if (requireNamespace("gssr", quietly = TRUE)) {
  data("gss_all", package = "gssr")
  gss_raw <- gss_all[, vars]
  rm(gss_all)
  source_note <- "GSS 1972-2024 cumulative file via the gssr package"
} else {
  stop("No GSS data found. See the comments at the top of this script.")
}
message("Data source: ", source_note)

# ---- 2. Clean ---------------------------------------------------------------
# zap_labels() turns labelled Stata columns into plain numbers.
# GSS missing codes (don't know, no answer, not asked) are already NA.
gss <- gss_raw |>
  zap_labels() |>
  mutate(across(everything(), as.numeric)) |>
  mutate(
    age_group = cut(age,
                    breaks = c(17, 24, 34, 44, 59, Inf),
                    labels = c("18-24", "25-34", "35-44", "45-59", "60+")),
    # Survey period, used in the regressions
    period = cut(year,
                 breaks = c(1971, 1979, 1989, 1999, 2009, 2018, 2024),
                 labels = c("1970s", "1980s", "1990s", "2000s", "2010-2018", "2021-2024")),
    # Interview mode: before 2004 every interview was in person
    mode_label = case_when(
      year < 2004 ~ "In person",
      mode == 1   ~ "In person",
      mode == 2   ~ "Phone",
      mode %in% c(3, 4) ~ "Web/multimode",
      TRUE ~ NA_character_),
    # Binary indicators (NA stays NA)
    very_happy          = as.numeric(happy == 1),
    people_trusted      = as.numeric(trust == 1),
    better_than_parents = as.numeric(parsol %in% c(1, 2)),
    better_than_parents = ifelse(is.na(parsol), NA, better_than_parents),
    friends_weekly      = as.numeric(socfrend %in% c(1, 2)),   # almost daily or once/twice a week
    friends_weekly      = ifelse(is.na(socfrend), NA, friends_weekly),
    # 1972-1974 have no PSU/strata codes; treat each year as one stratum and
    # each respondent as their own PSU (simple random sample assumption)
    vstrat = ifelse(is.na(vstrat), year * 10000, vstrat),
    vpsu   = ifelse(is.na(vpsu), id, vpsu)
  )

message("Respondents: ", nrow(gss), "  Years: ", min(gss$year), "-", max(gss$year))

# ---- 3. Save ----------------------------------------------------------------
saveRDS(gss, "data/gss_extract.rds")
write.csv(gss, "data/gss_extract.csv", row.names = FALSE)

con <- dbConnect(SQLite(), "data/gss.sqlite")
dbWriteTable(con, "gss", gss |> mutate(age_group = as.character(age_group),
                                       period    = as.character(period)),
             overwrite = TRUE)
print(dbGetQuery(con, "SELECT COUNT(*) AS respondents, COUNT(DISTINCT year) AS survey_years FROM gss"))
dbDisconnect(con)
