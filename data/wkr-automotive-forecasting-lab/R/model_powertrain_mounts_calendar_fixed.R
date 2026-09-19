# ============================================================
# model_powertrain_mounts.R
# WKR Komponenten KGaA
# First exploratory time-series modeling step: Powertrain Mounts
# ============================================================

sales_file <- file.path("data", "sales", "sales_daily_de.csv")
auto_file  <- file.path("data", "raw", "automotive_market_de.csv")

if (!file.exists(sales_file)) stop("Missing file: ", sales_file)
if (!file.exists(auto_file)) stop("Missing file: ", auto_file)

sales <- read.csv(sales_file, stringsAsFactors = FALSE)
auto  <- read.csv(auto_file, stringsAsFactors = FALSE)

required_sales <- c("date", "segment", "net_sales_eur")
required_auto <- c(
  "month", "vehicle_production_de",
  "registrations_total_de", "registrations_bev"
)

missing_sales <- setdiff(required_sales, names(sales))
missing_auto  <- setdiff(required_auto, names(auto))

if (length(missing_sales) > 0L) {
  stop("Missing sales columns: ", paste(missing_sales, collapse = ", "))
}
if (length(missing_auto) > 0L) {
  stop("Missing automotive columns: ", paste(missing_auto, collapse = ", "))
}

sales$date <- as.Date(sales$date)
auto$month <- as.Date(auto$month)

if (anyNA(sales$date)) stop("Could not parse sales$date.")
if (anyNA(auto$month)) stop("Could not parse auto$month.")

# ------------------------------------------------------------
# 1. Select first segment
# ------------------------------------------------------------
pm <- sales[sales$segment == "Powertrain Mounts", ]

if (nrow(pm) == 0L) stop("No rows found for segment 'Powertrain Mounts'.")

pm$month <- as.Date(format(pm$date, "%Y-%m-01"))

auto$bev_share <- auto$registrations_bev / auto$registrations_total_de

if (any(auto$bev_share <= 0 | auto$bev_share >= 1, na.rm = TRUE)) {
  stop("BEV share outside (0,1) in automotive data.")
}

# ------------------------------------------------------------
# 2. Join monthly automotive environment to daily WKR sales
# ------------------------------------------------------------
pm <- merge(
  pm,
  auto[, c("month", "vehicle_production_de", "bev_share")],
  by = "month",
  all.x = TRUE,
  sort = FALSE
)

pm <- pm[order(pm$date), ]

# Use numeric weekday independent of operating-system language.
# as.POSIXlt()$wday: Sunday=0, Monday=1, ..., Saturday=6
wday_num <- as.POSIXlt(pm$date)$wday
pm$weekday <- factor(
  wday_num,
  levels = c(1, 2, 3, 4, 5, 6, 0),
  labels = c(
    "Monday", "Tuesday", "Wednesday", "Thursday",
    "Friday", "Saturday", "Sunday"
  )
)

pm$log_sales <- log1p(pm$net_sales_eur)

# ------------------------------------------------------------
# 3. Restrict exploratory modeling sample to observed auto data
#    Sep-Dec 2026 are deliberately not filled from the forecast yet.
# ------------------------------------------------------------
pm_observed <- pm[complete.cases(pm[, c(
  "net_sales_eur", "vehicle_production_de", "bev_share"
)]), ]

if (nrow(pm_observed) < 365L) {
  stop("Too few complete observed rows for Powertrain Mounts: ", nrow(pm_observed))
}

# ------------------------------------------------------------
# 4. Console diagnostics
# ------------------------------------------------------------
cat("\nPowertrain Mounts modeling data\n")
cat("================================\n")
cat("All daily rows:       ", nrow(pm), "\n")
cat("Observed-model rows:  ", nrow(pm_observed), "\n")
cat("Full date range:      ", format(min(pm$date)), "to", format(max(pm$date)), "\n")
cat(
  "Observed auto range: ",
  format(min(pm_observed$date)), "to", format(max(pm_observed$date)), "\n"
)

cat("\nMissing values in full daily data\n")
print(colSums(is.na(pm[, c(
  "net_sales_eur", "vehicle_production_de", "bev_share"
)])))

cat("\nDaily net sales summary (observed-model sample)\n")
print(summary(pm_observed$net_sales_eur))

# ------------------------------------------------------------
# 5. First visual inspection
# ------------------------------------------------------------
old_par <- par(no.readonly = TRUE)
on.exit(par(old_par), add = TRUE)

par(mfrow = c(2, 1), mar = c(4, 4, 3, 1))

plot(
  pm_observed$date,
  pm_observed$net_sales_eur,
  type = "l",
  xlab = "Date",
  ylab = "Net sales EUR",
  main = "Powertrain Mounts - daily net sales"
)

acf(
  pm_observed$log_sales,
  lag.max = 35,
  na.action = na.pass,
  main = "Powertrain Mounts - ACF of log daily sales"
)

# ------------------------------------------------------------
# 6. Numeric ACF values for discussion
# ------------------------------------------------------------
acf_values <- acf(
  pm_observed$log_sales,
  lag.max = 35,
  plot = FALSE,
  na.action = na.pass
)$acf

acf_table <- data.frame(
  lag = 0:35,
  acf = as.numeric(acf_values)
)

cat("\nSelected ACF values\n")
cat("===================\n")
print(acf_table[acf_table$lag %in% c(1, 2, 3, 5, 7, 14, 21, 28), ], row.names = FALSE)

cat("\nNext step after inspecting this output:\n")
cat("Fit the first dynamic regression and inspect residual ACF/PACF.\n")


# ------------------------------------------------------------
# 7. First explanatory baseline
#
# log_sales ~ weekday + log(production) + BEV share
#
# No AR terms yet: first inspect what serial dependence remains after
# obvious calendar and structural effects.
# Train: 2022-01-01 ... 2025-12-31
# Test:  2026-01-01 ... 2026-08-31
# ------------------------------------------------------------

pm_observed$log_production <- log(pm_observed$vehicle_production_de)
pm_observed$bev_share_pp <- 100 * pm_observed$bev_share

train <- pm_observed[pm_observed$date <= as.Date("2025-12-31"), ]
test <- pm_observed[
  pm_observed$date >= as.Date("2026-01-01") &
    pm_observed$date <= as.Date("2026-08-31"),
]

if (nrow(train) == 0L || nrow(test) == 0L) stop("Train/test split failed.")

model_baseline <- lm(
  log_sales ~ weekday + log_production + bev_share_pp,
  data = train
)

cat("\nFirst explanatory baseline\n")
cat("==========================\n")
cat("Train rows:", nrow(train), "\n")
cat("Test rows: ", nrow(test), "\n\n")
print(summary(model_baseline))

# ------------------------------------------------------------
# 8. Structural coefficients in interpretable form
# ------------------------------------------------------------

coef_table <- coef(summary(model_baseline))

cat("\nStructural coefficients\n")
cat("=======================\n")

beta_prod <- coef(model_baseline)[["log_production"]]
beta_bev <- coef(model_baseline)[["bev_share_pp"]]

cat("Production elasticity (approx.):", round(beta_prod, 3), "\n")
cat(
  "Approx. sales change for +1 BEV percentage point:",
  round(100 * (exp(beta_bev) - 1), 2), "%\n"
)
cat(
  "Approx. sales change for +10 BEV percentage points:",
  round(100 * (exp(10 * beta_bev) - 1), 2), "%\n"
)

# ------------------------------------------------------------
# 9. Holdout performance: Jan-Aug 2026
# ------------------------------------------------------------

test$pred_log_sales <- predict(model_baseline, newdata = test)
test$pred_sales_eur <- pmax(0, exp(test$pred_log_sales) - 1)

mae <- mean(abs(test$net_sales_eur - test$pred_sales_eur))
rmse <- sqrt(mean((test$net_sales_eur - test$pred_sales_eur)^2))
mape <- mean(
  abs(test$net_sales_eur - test$pred_sales_eur) / test$net_sales_eur
) * 100

cat("\nHoldout performance: Jan-Aug 2026\n")
cat("=================================\n")
cat("MAE:  ", round(mae), "EUR\n")
cat("RMSE: ", round(rmse), "EUR\n")
cat("MAPE: ", round(mape, 2), "%\n")

# ------------------------------------------------------------
# 10. Residual dependence
# ------------------------------------------------------------

train$residual_baseline <- residuals(model_baseline)

resid_acf <- acf(
  train$residual_baseline,
  lag.max = 35,
  plot = FALSE
)$acf

resid_acf_table <- data.frame(
  lag = 0:35,
  acf = as.numeric(resid_acf)
)

cat("\nResidual ACF after baseline\n")
cat("===========================\n")
print(
  resid_acf_table[
    resid_acf_table$lag %in% c(1, 2, 3, 5, 7, 14, 21, 28),
  ],
  row.names = FALSE
)

dev.new()
par(mfrow = c(2, 1), mar = c(4, 4, 3, 1))

acf(
  train$residual_baseline,
  lag.max = 35,
  main = "Baseline residual ACF - Powertrain Mounts"
)

pacf(
  train$residual_baseline,
  lag.max = 35,
  main = "Baseline residual PACF - Powertrain Mounts"
)

cat("\nInterpretation checkpoint\n")
cat("=========================\n")
cat(
  "Raw lag-7 ACF:",
  round(acf_table$acf[acf_table$lag == 7], 3), "\n"
)
cat(
  "Residual lag-7 ACF:",
  round(resid_acf_table$acf[resid_acf_table$lag == 7], 3), "\n"
)
cat(
  "If residual lag-7 remains substantial, weekday fixed effects alone\n",
  "do not capture the weekly dynamics. That is our empirical reason to\n",
  "add a seasonal/dynamic AR component next.\n",
  sep = ""
)


# ------------------------------------------------------------
# 11. Dynamic comparison: baseline vs AR(1) vs AR(1) + AR(7)
# One-step-ahead diagnostic on the Jan-Aug 2026 holdout.
# ------------------------------------------------------------
pm_dynamic <- pm_observed
pm_dynamic$lag1_log_sales <- c(NA, head(pm_dynamic$log_sales, -1))
pm_dynamic$lag7_log_sales <- c(rep(NA, 7), head(pm_dynamic$log_sales, -7))

train_dynamic <- pm_dynamic[pm_dynamic$date <= as.Date("2025-12-31"), ]
test_dynamic <- pm_dynamic[
  pm_dynamic$date >= as.Date("2026-01-01") &
    pm_dynamic$date <= as.Date("2026-08-31"), ]

model_ar1 <- lm(
  log_sales ~ weekday + log_production + bev_share_pp + lag1_log_sales,
  data = train_dynamic
)
model_ar1_ar7 <- lm(
  log_sales ~ weekday + log_production + bev_share_pp +
    lag1_log_sales + lag7_log_sales,
  data = train_dynamic
)

evaluate_model <- function(model, newdata, model_name) {
  pred_log <- predict(model, newdata = newdata)
  pred_sales <- pmax(0, exp(pred_log) - 1)
  ok <- is.finite(pred_sales) & is.finite(newdata$net_sales_eur)
  actual <- newdata$net_sales_eur[ok]
  pred <- pred_sales[ok]
  data.frame(
    model = model_name, n = length(actual),
    MAE = mean(abs(actual - pred)),
    RMSE = sqrt(mean((actual - pred)^2)),
    MAPE = mean(abs(actual - pred) / actual) * 100
  )
}

comparison <- rbind(
  evaluate_model(model_baseline, test_dynamic, "Baseline"),
  evaluate_model(model_ar1, test_dynamic, "AR(1)"),
  evaluate_model(model_ar1_ar7, test_dynamic, "AR(1) + AR(7)")
)
cat("\nDynamic model comparison - Jan-Aug 2026\n")
cat("========================================\n")
print(comparison, row.names = FALSE, digits = 4)

cat("\nAR coefficients\n")
cat("===============\n")
cat("AR(1) model: lag 1 =", round(coef(model_ar1)[["lag1_log_sales"]], 3), "\n")
cat(
  "AR(1)+AR(7) model: lag 1 =",
  round(coef(model_ar1_ar7)[["lag1_log_sales"]], 3),
  "; lag 7 =", round(coef(model_ar1_ar7)[["lag7_log_sales"]], 3), "\n"
)

structural_comparison <- data.frame(
  model = c("Baseline", "AR(1)", "AR(1) + AR(7)"),
  production_elasticity = c(
    coef(model_baseline)[["log_production"]],
    coef(model_ar1)[["log_production"]],
    coef(model_ar1_ar7)[["log_production"]]
  ),
  bev_effect_10pp_pct = 100 * (
    exp(10 * c(
      coef(model_baseline)[["bev_share_pp"]],
      coef(model_ar1)[["bev_share_pp"]],
      coef(model_ar1_ar7)[["bev_share_pp"]]
    )) - 1
  )
)
cat("\nStructural coefficients across models\n")
cat("=====================================\n")
print(structural_comparison, row.names = FALSE, digits = 4)

residual_acf_selected <- function(model, model_name) {
  a <- as.numeric(acf(residuals(model), lag.max = 14, plot = FALSE)$acf)
  data.frame(model = model_name, lag1 = a[2], lag2 = a[3],
             lag7 = a[8], lag14 = a[15])
}
residual_comparison <- rbind(
  residual_acf_selected(model_baseline, "Baseline"),
  residual_acf_selected(model_ar1, "AR(1)"),
  residual_acf_selected(model_ar1_ar7, "AR(1) + AR(7)")
)
cat("\nResidual ACF comparison\n")
cat("=======================\n")
print(residual_comparison, row.names = FALSE, digits = 4)

dev.new()
par(mfrow = c(2, 1), mar = c(4, 4, 3, 1))
acf(residuals(model_ar1), lag.max = 35, main = "Residual ACF - AR(1)")
acf(residuals(model_ar1_ar7), lag.max = 35,
    main = "Residual ACF - AR(1) + AR(7)")

cat("\nDynamic-model checkpoint\n")
cat("========================\n")
cat(
  "Compare holdout error, residual ACF, and stability of the production/BEV\n",
  "coefficients. AR(7) must earn its place; the raw lag-7 ACF is not enough.\n",
  sep = ""
)


# ------------------------------------------------------------
# 14. Recursive holdout evaluation
#
# The previous AR comparison was one-step-ahead: observed past sales
# were available inside the holdout. That is useful diagnostically but
# optimistic for our actual Sep-Dec 2026 task.
#
# Now forecast the entire Jan-Aug 2026 holdout recursively. From
# 2026-01-01 onward, lagged sales come from earlier predictions whenever
# the required date is already inside the holdout.
# ------------------------------------------------------------

recursive_predict <- function(model, history_data, future_data,
                              use_lag1 = FALSE, use_lag7 = FALSE) {

  future_data <- future_data[order(future_data$date), ]
  history_data <- history_data[order(history_data$date), ]

  known_log_sales <- setNames(
    history_data$log_sales,
    as.character(history_data$date)
  )

  pred_log <- rep(NA_real_, nrow(future_data))

  for (i in seq_len(nrow(future_data))) {

    current_date <- future_data$date[i]
    row_i <- future_data[i, , drop = FALSE]

    if (use_lag1) {
      key1 <- as.character(current_date - 1)
      if (!key1 %in% names(known_log_sales)) {
        stop("Missing recursive lag-1 value for ", current_date)
      }
      row_i$lag1_log_sales <- known_log_sales[[key1]]
    }

    if (use_lag7) {
      key7 <- as.character(current_date - 7)
      if (!key7 %in% names(known_log_sales)) {
        stop("Missing recursive lag-7 value for ", current_date)
      }
      row_i$lag7_log_sales <- known_log_sales[[key7]]
    }

    pred_log[i] <- predict(model, newdata = row_i)
    known_log_sales[as.character(current_date)] <- pred_log[i]
  }

  pmax(0, exp(pred_log) - 1)
}

history_to_2025 <- pm_dynamic[
  pm_dynamic$date <= as.Date("2025-12-31"),
]

recursive_test <- pm_dynamic[
  pm_dynamic$date >= as.Date("2026-01-01") &
    pm_dynamic$date <= as.Date("2026-08-31"),
]

recursive_test$pred_baseline <- pmax(
  0,
  exp(predict(model_baseline, newdata = recursive_test)) - 1
)

recursive_test$pred_ar1_recursive <- recursive_predict(
  model_ar1,
  history_to_2025,
  recursive_test,
  use_lag1 = TRUE,
  use_lag7 = FALSE
)

recursive_test$pred_ar1_ar7_recursive <- recursive_predict(
  model_ar1_ar7,
  history_to_2025,
  recursive_test,
  use_lag1 = TRUE,
  use_lag7 = TRUE
)

evaluate_predictions <- function(actual, predicted, model_name) {
  ok <- is.finite(actual) & is.finite(predicted)
  actual <- actual[ok]
  predicted <- predicted[ok]

  data.frame(
    model = model_name,
    n = length(actual),
    MAE = mean(abs(actual - predicted)),
    RMSE = sqrt(mean((actual - predicted)^2)),
    MAPE = mean(abs(actual - predicted) / actual) * 100
  )
}

recursive_comparison <- rbind(
  evaluate_predictions(
    recursive_test$net_sales_eur,
    recursive_test$pred_baseline,
    "Baseline"
  ),
  evaluate_predictions(
    recursive_test$net_sales_eur,
    recursive_test$pred_ar1_recursive,
    "AR(1) recursive"
  ),
  evaluate_predictions(
    recursive_test$net_sales_eur,
    recursive_test$pred_ar1_ar7_recursive,
    "AR(1)+AR(7) recursive"
  )
)

cat("\nRecursive holdout comparison - Jan-Aug 2026\n")
cat("============================================\n")
print(recursive_comparison, row.names = FALSE, digits = 4)

# Monthly aggregation is diagnostic only. The model and target remain daily.
# This tells us whether daily errors cancel or create systematic monthly bias.
recursive_test$month_eval <- as.Date(
  format(recursive_test$date, "%Y-%m-01")
)

monthly_actual <- aggregate(
  net_sales_eur ~ month_eval,
  data = recursive_test,
  FUN = sum
)

monthly_baseline <- aggregate(
  pred_baseline ~ month_eval,
  data = recursive_test,
  FUN = sum
)

monthly_ar1 <- aggregate(
  pred_ar1_recursive ~ month_eval,
  data = recursive_test,
  FUN = sum
)

monthly_ar1_ar7 <- aggregate(
  pred_ar1_ar7_recursive ~ month_eval,
  data = recursive_test,
  FUN = sum
)

monthly_eval <- Reduce(
  function(x, y) merge(x, y, by = "month_eval"),
  list(
    monthly_actual,
    monthly_baseline,
    monthly_ar1,
    monthly_ar1_ar7
  )
)

monthly_eval$baseline_error_pct <- 100 * (
  monthly_eval$pred_baseline / monthly_eval$net_sales_eur - 1
)

monthly_eval$ar1_error_pct <- 100 * (
  monthly_eval$pred_ar1_recursive / monthly_eval$net_sales_eur - 1
)

monthly_eval$ar1_ar7_error_pct <- 100 * (
  monthly_eval$pred_ar1_ar7_recursive / monthly_eval$net_sales_eur - 1
)

cat("\nRecursive monthly bias diagnostic\n")
cat("=================================\n")
print(
  monthly_eval[, c(
    "month_eval",
    "net_sales_eur",
    "baseline_error_pct",
    "ar1_error_pct",
    "ar1_ar7_error_pct"
  )],
  row.names = FALSE,
  digits = 4
)

cat("\nForecast-horizon checkpoint\n")
cat("===========================\n")
cat(
  "The one-step-ahead comparison measures short-run updating ability.\n",
  "The recursive comparison is much closer to the Sep-Dec business task.\n",
  "If AR gains disappear recursively, we should not choose an AR model\n",
  "just because it wins when yesterday's actual sales are known.\n",
  sep = ""
)

# ------------------------------------------------------------
# 15. Stationarity / latent-level diagnostic
#
# Test the BASELINE RESIDUALS, not raw sales. The question is whether
# the unexplained component behaves like a stable stationary process
# or contains a slowly moving level / unit-root-like component.
#
# ADF:  H0 = unit root
# KPSS: H0 = level stationarity
# ------------------------------------------------------------

if (!requireNamespace("tseries", quietly = TRUE)) {
  stop(
    "Package 'tseries' is required for ADF/KPSS diagnostics. ",
    "Install it once with install.packages('tseries')."
  )
}

baseline_resid <- residuals(model_baseline)
baseline_dates <- train$date

cat("\nStationarity diagnostics - baseline residuals\n")
cat("=============================================\n")

adf_resid <- tseries::adf.test(baseline_resid, alternative = "stationary")
kpss_level_resid <- tseries::kpss.test(baseline_resid, null = "Level")
kpss_trend_resid <- tseries::kpss.test(baseline_resid, null = "Trend")

cat("\nADF test (H0: unit root)\n")
print(adf_resid)

cat("\nKPSS level test (H0: level stationary)\n")
print(kpss_level_resid)

cat("\nKPSS trend test (H0: trend stationary)\n")
print(kpss_trend_resid)

# ------------------------------------------------------------
# 16. Slow-moving residual level
# ------------------------------------------------------------

rolling_mean <- function(x, k) {
  stats::filter(x, rep(1 / k, k), sides = 1)
}

resid_diag <- data.frame(
  date = baseline_dates,
  residual = baseline_resid,
  rolling_30 = as.numeric(rolling_mean(baseline_resid, 30)),
  rolling_90 = as.numeric(rolling_mean(baseline_resid, 90)),
  cumulative_residual = cumsum(baseline_resid)
)

# Monthly means are diagnostic only; the model remains daily.
resid_diag$month <- as.Date(format(resid_diag$date, "%Y-%m-01"))
monthly_resid <- aggregate(
  residual ~ month,
  data = resid_diag,
  FUN = mean
)

cat("\nMonthly mean baseline residuals - last 18 training months\n")
cat("=========================================================\n")
print(tail(monthly_resid, 18), row.names = FALSE, digits = 4)

# ------------------------------------------------------------
# 17. Visual diagnostics
# ------------------------------------------------------------

dev.new()
par(mfrow = c(3, 1), mar = c(4, 4, 3, 1))

plot(
  resid_diag$date,
  resid_diag$residual,
  type = "l",
  xlab = "Date",
  ylab = "Residual",
  main = "Baseline residuals - Powertrain Mounts"
)
abline(h = 0, lty = 2)

plot(
  resid_diag$date,
  resid_diag$rolling_30,
  type = "l",
  xlab = "Date",
  ylab = "Rolling mean",
  main = "30-day and 90-day rolling residual means"
)
lines(resid_diag$date, resid_diag$rolling_90, lty = 2)
abline(h = 0, lty = 3)
legend(
  "topright",
  legend = c("30-day", "90-day"),
  lty = c(1, 2),
  bty = "n"
)

plot(
  resid_diag$date,
  resid_diag$cumulative_residual,
  type = "l",
  xlab = "Date",
  ylab = "Cumulative residual",
  main = "Cumulative baseline residual"
)
abline(h = 0, lty = 2)

cat("\nStationarity checkpoint\n")
cat("=======================\n")
cat(
  "Read ADF and KPSS jointly and compare them with the rolling/cumulative\n",
  "residual plots. If the residual level visibly drifts despite short-run\n",
  "mean reversion, the next candidate is a dynamic regression with a\n",
  "stochastic local level rather than another collection of AR lags.\n",
  sep = ""
)


# ============================================================
# 17. Calendar-augmented v1 model and Sep-Dec 2026 forecast
# ============================================================

calendar_path <- "data/raw/datumlanderferienfeiertage.csv"
forecast_auto_path <- "data/forecast/automotive_market_de_forecast_2026.csv"

if (!file.exists(calendar_path)) stop("Missing calendar file: ", calendar_path)
if (!file.exists(forecast_auto_path)) stop("Missing automotive forecast: ", forecast_auto_path)

# The calendar export is semicolon-separated. Detect the delimiter rather
# than relying on read.csv()'s comma default.
first_line <- readLines(
  calendar_path,
  n = 1,
  warn = FALSE,
  encoding = "UTF-8"
)

calendar_sep <- if (grepl(";", first_line, fixed = TRUE)) ";" else ","

calendar_raw <- read.table(
  calendar_path,
  header = TRUE,
  sep = calendar_sep,
  check.names = FALSE,
  fileEncoding = "UTF-8-BOM",
  stringsAsFactors = FALSE,
  quote = "\"",
  comment.char = ""
)

# Remove a possible BOM/whitespace artifact from column names.
names(calendar_raw) <- trimws(sub("^\\ufeff", "", names(calendar_raw)))

cat("\nCalendar import\n")
cat("===============\n")
cat("Separator:", ifelse(calendar_sep == ";", "semicolon", "comma"), "\n")
cat("Rows:", nrow(calendar_raw), " Columns:", ncol(calendar_raw), "\n")
cat("Columns:", paste(names(calendar_raw), collapse = " | "), "\n")

# Robust date-column detection.
date_candidates <- c("Datum", "date", "Date")
calendar_date_col <- date_candidates[date_candidates %in% names(calendar_raw)][1]

if (length(calendar_date_col) == 0L || is.na(calendar_date_col)) {
  stop(
    "No calendar date column found. Imported columns: ",
    paste(names(calendar_raw), collapse = " | ")
  )
}

calendar_date_text <- trimws(as.character(calendar_raw[[calendar_date_col]]))

# Calendar export uses German-style dates (e.g. 01.01.2022).
# Parse explicitly; fall back to ISO dates if the export format changes.
if (all(grepl("^\\d{2}\\.\\d{2}\\.\\d{4}$", calendar_date_text) | is.na(calendar_date_text))) {
  calendar_raw$calendar_date <- as.Date(calendar_date_text, format = "%d.%m.%Y")
} else if (all(grepl("^\\d{4}-\\d{2}-\\d{2}$", calendar_date_text) | is.na(calendar_date_text))) {
  calendar_raw$calendar_date <- as.Date(calendar_date_text, format = "%Y-%m-%d")
} else {
  stop(
    "Unsupported calendar date format. First values: ",
    paste(head(calendar_date_text, 5), collapse = " | ")
  )
}

if (anyNA(calendar_raw$calendar_date)) {
  stop("Calendar contains unparseable dates.")
}

# Detect state column.
state_candidates <- c("Bundesland", "state", "State")
state_col <- state_candidates[state_candidates %in% names(calendar_raw)][1]
if (is.na(state_col)) stop("No Bundesland/state column found in calendar.")

# Numeric/logical holiday columns, excluding date/state and school holiday.
candidate_cols <- setdiff(
  names(calendar_raw),
  c(calendar_date_col, state_col, "calendar_date", "Ferien")
)

is_indicator <- function(x) {
  if (is.logical(x)) return(TRUE)
  if (is.numeric(x)) {
    vals <- unique(x[!is.na(x)])
    return(length(vals) > 0 && all(vals %in% c(0, 1)))
  }
  vals <- unique(trimws(tolower(as.character(x[!is.na(x)]))))
  length(vals) > 0 && all(vals %in% c("0", "1", "true", "false", "ja", "nein"))
}

holiday_cols <- candidate_cols[
  vapply(calendar_raw[candidate_cols], is_indicator, logical(1))
]

to_indicator <- function(x) {
  if (is.logical(x)) return(as.numeric(x))
  if (is.numeric(x)) return(as.numeric(x > 0))
  as.numeric(trimws(tolower(as.character(x))) %in% c("1", "true", "ja"))
}

if (length(holiday_cols) > 0) {
  holiday_matrix <- sapply(calendar_raw[holiday_cols], to_indicator)
  if (is.null(dim(holiday_matrix))) holiday_matrix <- matrix(holiday_matrix, ncol = 1)
  calendar_raw$public_holiday <- as.numeric(rowSums(holiday_matrix, na.rm = TRUE) > 0)
} else {
  stop("No public-holiday indicator columns detected.")
}

# School holiday indicator.
if ("Ferien" %in% names(calendar_raw)) {
  ferien <- calendar_raw$Ferien
  if (is.numeric(ferien) || is.logical(ferien)) {
    calendar_raw$school_holiday <- as.numeric(ferien > 0)
  } else {
    z <- trimws(tolower(as.character(ferien)))
    calendar_raw$school_holiday <- as.numeric(
      !is.na(z) & z != "" & !(z %in% c("0", "false", "nein", "none", "keine"))
    )
  }
} else {
  calendar_raw$school_holiday <- 0
}

# WKR German footprint: Niedersachsen is deliberately weighted more strongly
# because of the historically VW-heavy footprint. Other represented states
# receive equal residual weight.
states <- sort(unique(as.character(calendar_raw[[state_col]])))
state_weights <- rep(1, length(states))
names(state_weights) <- states

nds_match <- grepl("niedersachsen", tolower(states))
if (any(nds_match)) state_weights[nds_match] <- 2
state_weights <- state_weights / sum(state_weights)

calendar_raw$state_weight <- state_weights[
  match(as.character(calendar_raw[[state_col]]), names(state_weights))
]

weighted_daily <- function(values, dates, weights) {
  tmp <- data.frame(date = dates, value = values, weight = weights)
  tmp$weighted <- tmp$value * tmp$weight
  aggregate(weighted ~ date, data = tmp, FUN = sum)
}

holiday_daily <- weighted_daily(
  calendar_raw$public_holiday,
  calendar_raw$calendar_date,
  calendar_raw$state_weight
)
names(holiday_daily)[2] <- "holiday_intensity"

school_daily <- weighted_daily(
  calendar_raw$school_holiday,
  calendar_raw$calendar_date,
  calendar_raw$state_weight
)
names(school_daily)[2] <- "school_holiday_intensity"

calendar_daily <- merge(holiday_daily, school_daily, by = "date", all = TRUE)
calendar_daily$month_num <- as.integer(format(calendar_daily$date, "%m"))
calendar_daily$day_num <- as.integer(format(calendar_daily$date, "%d"))

# Parsimonious shutdown proxies matching known business timing.
calendar_daily$summer_shutdown <- as.numeric(
  calendar_daily$month_num %in% c(7, 8)
)
calendar_daily$year_end_shutdown <- as.numeric(
  calendar_daily$month_num == 12 & calendar_daily$day_num >= 20
)

# The supplied calendar ends before the full WKR sales horizon. Calendar
# features are deterministic, so extend them for uncovered dates instead of
# treating this as missing business data.
all_dates <- data.frame(
  date = seq(min(pm$date), max(pm$date), by = "day")
)

calendar_daily <- merge(all_dates, calendar_daily, by = "date", all.x = TRUE)
calendar_daily <- calendar_daily[order(calendar_daily$date), ]

missing_calendar_dates <- calendar_daily$date[
  is.na(calendar_daily$holiday_intensity) |
    is.na(calendar_daily$school_holiday_intensity)
]

if (length(missing_calendar_dates) > 0L) {
  cat(
    "\nCalendar coverage gap:",
    format(min(missing_calendar_dates)), "to",
    format(max(missing_calendar_dates)),
    "- filling deterministic defaults for uncovered dates.\n"
  )
}

# For dates not contained in the source calendar, no listed public/school
# holiday is assumed. Shutdown features are reconstructed from the date itself.
calendar_daily$holiday_intensity[
  is.na(calendar_daily$holiday_intensity)
] <- 0

calendar_daily$school_holiday_intensity[
  is.na(calendar_daily$school_holiday_intensity)
] <- 0

calendar_daily$month_num <- as.integer(format(calendar_daily$date, "%m"))
calendar_daily$day_num <- as.integer(format(calendar_daily$date, "%d"))

calendar_daily$summer_shutdown <- as.numeric(
  calendar_daily$month_num %in% c(7, 8)
)
calendar_daily$year_end_shutdown <- as.numeric(
  calendar_daily$month_num == 12 & calendar_daily$day_num >= 20
)

pm_cal <- merge(pm, calendar_daily, by = "date", all.x = TRUE)
pm_cal <- pm_cal[order(pm_cal$date), ]

needed_cal <- c(
  "holiday_intensity", "school_holiday_intensity",
  "summer_shutdown", "year_end_shutdown"
)

if (anyNA(pm_cal[needed_cal])) {
  bad_dates <- pm_cal$date[!complete.cases(pm_cal[needed_cal])]
  stop(
    "Calendar merge still produced missing values. First affected dates: ",
    paste(head(format(bad_dates), 10), collapse = " | ")
  )
}

pm_cal$log_production <- log(pm_cal$vehicle_production_de)
pm_cal$bev_share_pp <- 100 * pm_cal$bev_share

train_cal <- pm_cal[
  pm_cal$date <= as.Date("2025-12-31") &
    !is.na(pm_cal$vehicle_production_de),
]
test_cal <- pm_cal[
  pm_cal$date >= as.Date("2026-01-01") &
    pm_cal$date <= as.Date("2026-08-31") &
    !is.na(pm_cal$vehicle_production_de),
]

model_calendar <- lm(
  log_sales ~ weekday +
    holiday_intensity +
    school_holiday_intensity +
    summer_shutdown +
    year_end_shutdown +
    log_production +
    bev_share_pp,
  data = train_cal
)

cat("\nCalendar-augmented v1 model\n")
cat("===========================\n")
print(summary(model_calendar))

test_cal$pred_calendar <- pmax(
  0, exp(predict(model_calendar, newdata = test_cal)) - 1
)

calendar_holdout <- evaluate_predictions(
  test_cal$net_sales_eur,
  test_cal$pred_calendar,
  "Calendar v1"
)

cat("\nCalendar v1 holdout - Jan-Aug 2026\n")
cat("===================================\n")
print(calendar_holdout, row.names = FALSE, digits = 4)

cal_resid_acf <- as.numeric(
  acf(residuals(model_calendar), lag.max = 14, plot = FALSE)$acf
)

cat("\nCalendar v1 residual ACF\n")
cat("========================\n")
print(
  data.frame(
    lag = c(1, 2, 7, 14),
    acf = cal_resid_acf[c(2, 3, 8, 15)]
  ),
  row.names = FALSE,
  digits = 4
)

# Diagnostics remain in the pipeline, but do not gate the workflow.
if (requireNamespace("tseries", quietly = TRUE)) {
  cat("\nCalendar v1 ADF residual test\n")
  print(tseries::adf.test(residuals(model_calendar)))
  cat("\nCalendar v1 KPSS level residual test\n")
  print(tseries::kpss.test(residuals(model_calendar), null = "Level"))
  cat("\nCalendar v1 KPSS trend residual test\n")
  print(tseries::kpss.test(residuals(model_calendar), null = "Trend"))
}

# ------------------------------------------------------------
# 18. Refit through Aug 2026 and forecast Sep-Dec 2026
# ------------------------------------------------------------

auto_fc <- read.csv(forecast_auto_path, check.names = FALSE)
auto_fc$month <- as.Date(auto_fc$month)

required_fc <- c(
  "month", "vehicle_production_de",
  "registrations_total_de", "registrations_bev"
)
missing_fc <- setdiff(required_fc, names(auto_fc))
if (length(missing_fc) > 0) {
  stop("Automotive forecast missing columns: ", paste(missing_fc, collapse = ", "))
}

auto_fc$bev_share <- auto_fc$registrations_bev / auto_fc$registrations_total_de

future <- pm_cal[
  pm_cal$date >= as.Date("2026-09-01") &
    pm_cal$date <= as.Date("2026-12-31"),
]

# Replace the temporary DGP carry-forward automotive values with the
# dedicated Sep-Dec forecast/scenario inputs.
future$month <- as.Date(format(future$date, "%Y-%m-01"))
future$vehicle_production_de <- NULL
future$bev_share <- NULL

future <- merge(
  future,
  auto_fc[, c("month", "vehicle_production_de", "bev_share")],
  by = "month",
  all.x = TRUE
)
future <- future[order(future$date), ]

if (anyNA(future[, c("vehicle_production_de", "bev_share")])) {
  stop("Missing Sep-Dec automotive forecast values after merge.")
}

future$log_production <- log(future$vehicle_production_de)
future$bev_share_pp <- 100 * future$bev_share

refit_data <- pm_cal[
  pm_cal$date <= as.Date("2026-08-31") &
    !is.na(pm_cal$vehicle_production_de),
]

model_calendar_final <- lm(
  log_sales ~ weekday +
    holiday_intensity +
    school_holiday_intensity +
    summer_shutdown +
    year_end_shutdown +
    log_production +
    bev_share_pp,
  data = refit_data
)

future$forecast_net_sales_eur <- pmax(
  0,
  exp(predict(model_calendar_final, newdata = future)) - 1
)

forecast_daily <- future[, c(
  "date", "segment", "forecast_net_sales_eur",
  "vehicle_production_de", "bev_share"
)]

forecast_daily$month <- as.Date(format(forecast_daily$date, "%Y-%m-01"))

forecast_monthly <- aggregate(
  forecast_net_sales_eur ~ month,
  data = forecast_daily,
  FUN = sum
)

cat("\nPowertrain Mounts forecast - Sep-Dec 2026\n")
cat("==========================================\n")
print(forecast_monthly, row.names = FALSE, digits = 8)

cat("\nFinal structural coefficients\n")
cat("=============================\n")
beta_prod_final <- coef(model_calendar_final)[["log_production"]]
beta_bev_final <- coef(model_calendar_final)[["bev_share_pp"]]
cat("Production elasticity:", round(beta_prod_final, 4), "\n")
cat(
  "BEV effect for +10 percentage points:",
  round(100 * (exp(10 * beta_bev_final) - 1), 2), "%\n"
)

dir.create("data/forecast", recursive = TRUE, showWarnings = FALSE)

write.csv(
  forecast_daily,
  "data/forecast/powertrain_mounts_daily_forecast_2026.csv",
  row.names = FALSE
)

cat("\nWrote:\n")
cat("data/forecast/powertrain_mounts_daily_forecast_2026.csv\n")
cat("\nPowertrain Mounts v1 is ready for model review and pipeline hand-off.\n")
