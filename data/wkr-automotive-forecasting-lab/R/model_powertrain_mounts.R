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
