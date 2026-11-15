# =============================================================================
# 02_sql_summaries.R
# Run every query in sql/queries.sql and save each result as a CSV in output/.
# =============================================================================

library(DBI)
library(RSQLite)

con <- dbConnect(SQLite(), "data/gss.sqlite")

# Read the SQL file, drop comment lines, split into statements on ";"
sql_lines  <- readLines("sql/queries.sql")
sql_lines  <- sql_lines[!grepl("^\\s*--", sql_lines)]
statements <- trimws(strsplit(paste(sql_lines, collapse = "\n"), ";")[[1]])
statements <- statements[statements != ""]

# One name per query, in the order they appear in the file
query_names <- c("overall_summary", "response_distribution", "by_year",
                 "by_age_group", "happy_year_by_age", "change_by_period",
                 "mode_2022_2024")
stopifnot(length(statements) == length(query_names))

dir.create("output", showWarnings = FALSE)
for (i in seq_along(statements)) {
  res <- dbGetQuery(con, statements[i])
  write.csv(res, file.path("output", paste0("sql_", query_names[i], ".csv")),
            row.names = FALSE)
  cat("\n====", query_names[i], "====\n")
  print(head(res, 40))
}

dbDisconnect(con)
