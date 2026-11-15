# =============================================================================
# 03_analysis.R
# Weighted estimates, survey-mode check, logistic regressions and figures.
# Run after 01_prepare_data.R (and 02_sql_summaries.R for the SQL tables).
# =============================================================================

library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)
library(survey)

gss <- readRDS("data/gss_extract.rds")
dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)

# Some strata have a single PSU after subsetting; "adjust" handles that
options(survey.lonely.psu = "adjust")

# ---- Survey design ----------------------------------------------------------
# WTSSPS is the GSS post-stratification weight recommended for the 1972-2024
# cumulative file. VPSU / VSTRAT describe the clustered, stratified sample.
des <- svydesign(ids = ~vpsu, strata = ~vstrat, weights = ~wtssps,
                 nest = TRUE, data = gss)

# ---- Helper functions -------------------------------------------------------
# Weighted percentage of a 0/1 variable by group, with a 95% CI
weighted_pct <- function(var, by, design = des) {
  f   <- as.formula(paste0("~", var))
  sub <- subset(design, !is.na(get(var)))
  est <- svyby(f, as.formula(paste0("~", by)), sub, svymean, na.rm = TRUE)
  ci  <- confint(est)
  data.frame(group   = est[[by]],
             pct     = 100 * est[[var]],
             ci_low  = 100 * ci[, 1],
             ci_high = 100 * ci[, 2],
             row.names = NULL) |>
    setNames(c(by, "pct", "ci_low", "ci_high"))
}

# Unweighted percentage of a 0/1 variable by group
unweighted_pct <- function(var, by, data = gss) {
  data |>
    filter(!is.na(.data[[var]]), !is.na(.data[[by]])) |>
    group_by(.data[[by]]) |>
    summarise(pct = 100 * mean(.data[[var]]), n = n(), .groups = "drop")
}

# Odds ratios with 95% CIs from a survey logistic regression
or_table <- function(model, outcome) {
  est <- coef(model)
  ci  <- confint(model)
  data.frame(outcome    = outcome,
             term       = names(est),
             odds_ratio = exp(est),
             or_low     = exp(ci[, 1]),
             or_high    = exp(ci[, 2]),
             p_value    = coef(summary(model))[, 4],
             row.names  = NULL)
}

mode_break <- geom_vline(xintercept = 2019.5, linetype = "dashed", colour = "grey40")
mode_note  <- annotate("text", x = 2019, y = Inf, vjust = 1.5, hjust = 1, size = 3,
                       colour = "grey30", label = "2021+: COVID era and\nweb/multimode interviews")
theme_set(theme_minimal(base_size = 12))

# =============================================================================
# 1. Happiness and trust over time: weighted vs. unweighted
# =============================================================================
trend <- bind_rows(
  weighted_pct("very_happy", "year") |> mutate(indicator = "Very happy", type = "Weighted"),
  weighted_pct("people_trusted", "year") |> mutate(indicator = "Most people can be trusted", type = "Weighted"),
  unweighted_pct("very_happy", "year") |> mutate(indicator = "Very happy", type = "Unweighted"),
  unweighted_pct("people_trusted", "year") |> mutate(indicator = "Most people can be trusted", type = "Unweighted")
)
write.csv(trend, "output/trend_weighted_vs_unweighted.csv", row.names = FALSE)

for (ind in c("Very happy", "Most people can be trusted")) {
  d  <- filter(trend, indicator == ind)
  dw <- filter(d, type == "Weighted")
  p <- ggplot(d, aes(x = year, y = pct, colour = type)) +
    geom_ribbon(data = dw, aes(ymin = ci_low, ymax = ci_high),
                fill = "#1F77B4", alpha = 0.15, colour = NA) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 1.4) +
    mode_break + mode_note +
    scale_colour_manual(values = c(Weighted = "#1F77B4", Unweighted = "#ADB5BD"), name = NULL) +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    labs(title = paste0("Percentage saying \"", ind, "\" by survey year"),
         subtitle = "Weighted (WTSSPS) with 95% CI band vs. unweighted",
         x = "Survey year", y = NULL) +
    theme(legend.position = "top")
  fname <- ifelse(ind == "Very happy", "fig1_happy_trend.png", "fig2_trust_trend.png")
  ggsave(file.path("output/figures", fname), p, width = 8, height = 5, dpi = 150)
}

# =============================================================================
# 2. Age-group differences (weighted)
# =============================================================================
age_tbl <- bind_rows(
  weighted_pct("very_happy", "age_group")          |> mutate(indicator = "Very happy"),
  weighted_pct("people_trusted", "age_group")      |> mutate(indicator = "Most people can be trusted"),
  weighted_pct("friends_weekly", "age_group")      |> mutate(indicator = "Evenings with friends weekly+"),
  weighted_pct("better_than_parents", "age_group") |> mutate(indicator = "Better off than parents")
)
write.csv(age_tbl, "output/age_group_weighted.csv", row.names = FALSE)

p3 <- ggplot(age_tbl, aes(x = age_group, y = pct)) +
  geom_col(fill = "#1F77B4", width = 0.65) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.2) +
  facet_wrap(~indicator, nrow = 2) +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  labs(title = "Weighted percentages by age group, GSS 1972-2024",
       subtitle = "Error bars = 95% confidence intervals",
       x = "Age group", y = NULL)
ggsave("output/figures/fig3_age_groups.png", p3, width = 9, height = 6.5, dpi = 150)

# Full response distribution of SOCFREND by age group (ordinal -> stacked bars)
socfrend_labels <- c("Almost daily", "1-2 times a week", "Several times a month",
                     "About once a month", "Several times a year", "About once a year", "Never")
dist <- svyby(~factor(socfrend), ~age_group, subset(des, !is.na(socfrend) & !is.na(age_group)),
              svymean, na.rm = TRUE)
dist_long <- dist |>
  as.data.frame() |>
  select(age_group, starts_with("factor(socfrend)")) |>
  select(-starts_with("se.")) |>
  pivot_longer(-age_group, names_to = "response", values_to = "share") |>
  mutate(response = factor(socfrend_labels[as.integer(sub("factor\\(socfrend\\)", "", response))],
                           levels = socfrend_labels))
write.csv(dist_long, "output/socfrend_distribution_by_age.csv", row.names = FALSE)

p4 <- ggplot(dist_long, aes(x = age_group, y = share, fill = response)) +
  geom_col(width = 0.7) +
  scale_fill_brewer(palette = "RdYlBu", direction = -1, name = "Evenings with friends") +
  scale_y_continuous(labels = percent) +
  labs(title = "How often people spend a social evening with friends",
       subtitle = "Weighted response distribution (SOCFREND) by age group",
       x = "Age group", y = "Share of respondents")
ggsave("output/figures/fig4_socfrend_distribution.png", p4, width = 9, height = 5.5, dpi = 150)

# Happiness trend by age group (weighted)
happy_age_year <- svyby(~very_happy, ~year + age_group,
                        subset(des, !is.na(very_happy) & !is.na(age_group)),
                        svymean, na.rm = TRUE) |>
  as.data.frame() |>
  mutate(pct = 100 * very_happy)
write.csv(happy_age_year, "output/happy_year_by_age_weighted.csv", row.names = FALSE)

p5 <- ggplot(happy_age_year, aes(x = year, y = pct)) +
  geom_line(colour = "#1F77B4") +
  geom_point(colour = "#1F77B4", size = 1) +
  geom_vline(xintercept = 2019.5, linetype = "dashed", colour = "grey40") +
  facet_wrap(~age_group, nrow = 1) +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  labs(title = "Weighted percentage \"very happy\" by age group",
       subtitle = "Dashed line = 2021+ (COVID era, web/multimode interviews)",
       x = "Survey year", y = NULL)
ggsave("output/figures/fig5_happy_by_age_trend.png", p5, width = 11, height = 4, dpi = 150)

# =============================================================================
# 3. Survey-mode check, 2022 and 2024
#    TRUST is left out: in 2022 and 2024 it was asked almost only in person or
#    by phone (65 web answers), so a web-vs-in-person comparison is not possible.
# =============================================================================
des_mode <- subset(des, year %in% c(2022, 2024) & !is.na(mode_label))
mode_tbl <- bind_rows(
  weighted_pct("very_happy", "mode_label", des_mode)     |> mutate(indicator = "Very happy"),
  weighted_pct("friends_weekly", "mode_label", des_mode) |> mutate(indicator = "Evenings with friends weekly+")
)
write.csv(mode_tbl, "output/mode_2022_2024_weighted.csv", row.names = FALSE)

# Does mode still matter after accounting for age and year?
mode_model <- svyglm(very_happy ~ mode_label + age_group + factor(year),
                     design = subset(des_mode, !is.na(very_happy) & !is.na(age_group)),
                     family = quasibinomial())
mode_or <- or_table(mode_model, "Very happy (2022-2024, mode model)")

p6 <- ggplot(mode_tbl, aes(x = mode_label, y = pct, fill = mode_label)) +
  geom_col(width = 0.6) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.2) +
  facet_wrap(~indicator) +
  scale_fill_manual(values = c("In person" = "#1F77B4", "Phone" = "#ADB5BD",
                               "Web/multimode" = "#FF7F0E"), guide = "none") +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  labs(title = "Responses by interview mode, 2022 and 2024 (weighted)",
       subtitle = "Error bars = 95% CI. Respondents are not randomly assigned to mode.",
       x = NULL, y = NULL)
ggsave("output/figures/fig6_mode_check.png", p6, width = 9, height = 4.5, dpi = 150)

# =============================================================================
# 4. Logistic regressions: age group + survey period
# =============================================================================
m_happy <- svyglm(very_happy ~ age_group + period,
                  design = subset(des, !is.na(very_happy) & !is.na(age_group)),
                  family = quasibinomial())
m_trust <- svyglm(people_trusted ~ age_group + period,
                  design = subset(des, !is.na(people_trusted) & !is.na(age_group)),
                  family = quasibinomial())

or_all <- bind_rows(or_table(m_happy, "Very happy"),
                    or_table(m_trust, "Most people can be trusted"),
                    mode_or)
write.csv(or_all, "output/logistic_odds_ratios.csv", row.names = FALSE)
print(or_all, digits = 3)

or_plot <- or_all |>
  filter(outcome != "Very happy (2022-2024, mode model)", term != "(Intercept)") |>
  mutate(term = sub("age_group", "Age ", term),
         term = sub("period", "Period ", term),
         term = factor(term, levels = rev(unique(term))))

p7 <- ggplot(or_plot, aes(x = odds_ratio, y = term, colour = outcome)) +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "grey50") +
  geom_pointrange(aes(xmin = or_low, xmax = or_high),
                  position = position_dodge(width = 0.5)) +
  scale_x_log10() +
  scale_colour_manual(values = c("Very happy" = "#1F77B4",
                                 "Most people can be trusted" = "#FF7F0E"), name = NULL) +
  labs(title = "Weighted logistic regression: odds ratios with 95% CI",
       subtitle = "Reference groups: ages 18-24 and the 1970s. Log scale.",
       x = "Odds ratio", y = NULL) +
  theme(legend.position = "top")
ggsave("output/figures/fig7_odds_ratios.png", p7, width = 8, height = 5.5, dpi = 150)

# =============================================================================
# 5. Headline numbers used in the report
# =============================================================================
pick <- function(df, ind, yr, tp = "Weighted") {
  round(df$pct[df$indicator == ind & df$year == yr & df$type == tp], 1)
}
headline <- data.frame(
  measure = c("Very happy 1972 (unweighted)", "Very happy 2024 (unweighted)",
              "Very happy 1972 (weighted)", "Very happy 2018 (weighted)",
              "Very happy 2021 (weighted)", "Very happy 2024 (weighted)",
              "Trust 1972 (unweighted)", "Trust 2024 (unweighted)",
              "Trust 1972 (weighted)", "Trust 2018 (weighted)", "Trust 2024 (weighted)"),
  value = c(pick(trend, "Very happy", 1972, "Unweighted"), pick(trend, "Very happy", 2024, "Unweighted"),
            pick(trend, "Very happy", 1972), pick(trend, "Very happy", 2018),
            pick(trend, "Very happy", 2021), pick(trend, "Very happy", 2024),
            pick(trend, "Most people can be trusted", 1972, "Unweighted"),
            pick(trend, "Most people can be trusted", 2024, "Unweighted"),
            pick(trend, "Most people can be trusted", 1972),
            pick(trend, "Most people can be trusted", 2018),
            pick(trend, "Most people can be trusted", 2024)))
write.csv(headline, "output/headline_numbers.csv", row.names = FALSE)
print(headline)
print(age_tbl, digits = 3)
print(mode_tbl, digits = 3)

message("Analysis complete.")
