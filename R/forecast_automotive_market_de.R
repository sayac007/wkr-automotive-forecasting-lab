# ============================================================
# forecast_automotive_market_de.R
#
# QUICK & DIRTY v1
#
# Inputs:
#   data/raw/automotive_market_de.csv
#   data/raw/Wetterbericht MMM.csv
#
# Output:
#   data/forecast/automotive_market_de_forecast_2026.csv
#
# Idea:
#   registrations(t) ~ trend + month + weather(t-1)
#   production(t)    ~ trend + month
#   BEV share(t)     = latest observed share + robust recent logit trend
#
# Weather forecast:
#   monthly averages 2021-2025.
#
# Important implementation detail:
#   No ISO-week date conversion. On some Windows/R installations
#   %G/%V/%u caused the weather dates to become NA. For this v1
#   we assign each week to a month using the week's midpoint:
#   Jan 1 + 7*(week-1) + 3 days.
# ============================================================

auto_file    <- file.path("data", "raw", "automotive_market_de.csv")
weather_file <- file.path("data", "raw", "Wetterbericht MMM.csv")
output_dir   <- file.path("data", "forecast")
output_file  <- file.path(output_dir, "automotive_market_de_forecast_2026.csv")

# ---------- Input checks ----------
if (!file.exists(auto_file)) stop("Missing file: ", auto_file)
if (!file.exists(weather_file)) stop("Missing file: ", weather_file)

auto <- read.csv(auto_file, stringsAsFactors = FALSE)
weather <- read.csv(
  weather_file,
  sep = ";",
  stringsAsFactors = FALSE,
  check.names = FALSE
)

weather_vars <- c(
  "Lufttemperatur",
  "Bedeckungsgrad",
  "Windgeschwindigkeit",
  "Niederschlagshoehe",
  "Sonnenscheindauer"
)

required_auto <- c(
  "month",
  "vehicle_production_de",
  "registrations_total_de",
  "registrations_bev"
)

required_weather <- c("Woche", "Jahr", weather_vars)

missing_auto <- setdiff(required_auto, names(auto))
missing_weather <- setdiff(required_weather, names(weather))

if (length(missing_auto) > 0) {
  stop(
    "Missing columns in automotive_market_de.csv: ",
    paste(missing_auto, collapse = ", ")
  )
}

if (length(missing_weather) > 0) {
  stop(
    "Missing columns in Wetterbericht MMM.csv: ",
    paste(missing_weather, collapse = ", ")
  )
}

# ---------- Automotive dates ----------
auto$month <- as.Date(auto$month)
if (anyNA(auto$month)) stop("Could not parse automotive month.")

auto <- auto[order(auto$month), ]

# Explicit month key avoids Date-class merge problems.
auto$ym <- format(auto$month, "%Y-%m")

# ---------- Weather: week -> month ----------
# Robust quick & dirty assignment by midpoint of week.
year_start <- as.Date(paste0(weather$Jahr, "-01-01"))

weather$week_mid <- year_start +
  7 * (as.integer(weather$Woche) - 1L) + 3L

weather$ym <- format(weather$week_mid, "%Y-%m")
weather$month_num <- as.integer(format(weather$week_mid, "%m"))

if (anyNA(weather$week_mid)) {
  stop("Could not construct weather week dates.")
}

# ---------- Historical monthly weather ----------
monthly_weather <- aggregate(
  weather[, weather_vars],
  by = list(ym = weather$ym),
  FUN = mean,
  na.rm = TRUE
)

# Keep automotive rows; append weather by YYYY-MM key.
auto <- merge(
  auto,
  monthly_weather,
  by = "ym",
  all.x = TRUE,
  sort = FALSE
)

auto <- auto[order(auto$month), ]

cat("\nWeather merge check\n")
cat("===================\n")
cat("Automotive rows:", nrow(auto), "\n")
cat(
  "Rows with complete weather:",
  sum(complete.cases(auto[, weather_vars])),
  "\n"
)

if (sum(complete.cases(auto[, weather_vars])) < 24L) {
  stop(
    "Weather merge still failed: fewer than 24 complete monthly rows. ",
    "First automotive key: ", auto$ym[1],
    "; weather key range: ",
    min(monthly_weather$ym), " to ", max(monthly_weather$ym)
  )
}

# ---------- One-month weather lag ----------
lag_vars <- paste0(weather_vars, "_lag1")

for (i in seq_along(weather_vars)) {
  auto[[lag_vars[i]]] <- c(
    NA_real_,
    head(auto[[weather_vars[i]]], -1)
  )
}

# ---------- Modeling variables ----------
auto$t <- seq_len(nrow(auto))
auto$month_num <- as.integer(format(auto$month, "%m"))
auto$year <- as.integer(format(auto$month, "%Y"))

# Training only through Dec 2025.
train <- auto[
  auto$month >= as.Date("2022-01-01") &
  auto$month <= as.Date("2025-12-01"),
]

needed_train <- c(
  "registrations_total_de",
  "vehicle_production_de",
  "registrations_bev",
  "t",
  "month_num",
  lag_vars
)

train <- train[complete.cases(train[, needed_train]), ]

cat("Registration training rows:", nrow(train), "\n")

if (nrow(train) < 36L) {
  stop("Too few complete training rows: ", nrow(train))
}

# Month as factor only after the complete-case filtering.
train$month_factor <- factor(train$month_num, levels = 1:12)

if (length(unique(train$month_num)) < 12L) {
  stop(
    "Training data do not contain all 12 months. Months present: ",
    paste(sort(unique(train$month_num)), collapse = ", ")
  )
}

# ---------- 1. Total registrations ----------
registration_formula <- as.formula(
  paste(
    "registrations_total_de ~ t + month_factor +",
    paste(lag_vars, collapse = " + ")
  )
)

model_registrations <- lm(
  registration_formula,
  data = train
)

# ---------- 2. German vehicle production ----------
model_production <- lm(
  vehicle_production_de ~ t + month_factor,
  data = train
)

# ---------- 3. BEV share ----------
# BEV share is treated as a structural mix variable, not as a seasonal
# registration-level variable. We therefore avoid month dummies here.
#
# v1 rule:
#   1. anchor the forecast at the latest observed BEV share (Aug 2026)
#   2. estimate a robust monthly trend as the median month-to-month
#      change in logit(BEV share) over the latest 12 observed months
#   3. extrapolate that trend for Sep-Dec 2026
#
# This deliberately preserves continuity in drivetrain mix while allowing
# total registrations themselves to remain seasonal.

auto$bev_share <- auto$registrations_bev /
  auto$registrations_total_de

if (any(auto$bev_share <= 0 | auto$bev_share >= 1, na.rm = TRUE)) {
  stop("BEV share must be strictly between 0 and 1.")
}

bev_observed <- auto[
  !is.na(auto$bev_share) &
    auto$month <= as.Date("2026-08-01"),
  c("month", "bev_share")
]

bev_observed <- bev_observed[order(bev_observed$month), ]

if (nrow(bev_observed) < 12L) {
  stop("Too few observed BEV-share months.")
}

bev_recent <- tail(bev_observed, 12L)
bev_recent$logit_share <- qlogis(bev_recent$bev_share)

bev_monthly_step <- median(
  diff(bev_recent$logit_share),
  na.rm = TRUE
)

last_bev_share <- tail(bev_observed$bev_share, 1L)
last_bev_logit <- qlogis(last_bev_share)

cat("\nBEV-share forecast assumption\n")
cat("=============================\n")
cat(
  "Latest observed share:",
  round(100 * last_bev_share, 2), "%\n"
)
cat(
  "Median monthly logit step, latest 12 months:",
  round(bev_monthly_step, 4), "\n"
)

# ---------- Weather normals 2021-2025 ----------
weather_recent <- weather[
  weather$Jahr >= 2021 & weather$Jahr <= 2025,
]

weather_normals <- aggregate(
  weather_recent[, weather_vars],
  by = list(month_num = weather_recent$month_num),
  FUN = mean,
  na.rm = TRUE
)

# ---------- Forecast Sep-Dec 2026 ----------
future_dates <- seq(
  as.Date("2026-09-01"),
  as.Date("2026-12-01"),
  by = "month"
)

# Continue t from the full observed automotive series.
last_t <- max(auto$t)

future <- data.frame(
  month = future_dates,
  t = seq.int(last_t + 1L, last_t + length(future_dates)),
  month_num = as.integer(format(future_dates, "%m"))
)

future$month_factor <- factor(
  future$month_num,
  levels = 1:12
)

# For forecast month t, use climatological weather of month t-1.
# Sep <- Aug normal, Oct <- Sep normal, etc.
for (i in seq_along(future_dates)) {

  lag_date <- as.Date(format(
    future_dates[i] - 15,
    "%Y-%m-01"
  ))
  lag_month_num <- as.integer(format(lag_date, "%m"))

  normal_row <- weather_normals[
    weather_normals$month_num == lag_month_num,
  ]

  if (nrow(normal_row) != 1L) {
    stop("No unique weather normal for month ", lag_month_num)
  }

  for (j in seq_along(weather_vars)) {
    future[[lag_vars[j]]][i] <- normal_row[[weather_vars[j]]][1]
  }
}

# ---------- Predictions ----------
future$registrations_total_de <- round(
  predict(model_registrations, newdata = future)
)

future$vehicle_production_de <- round(
  predict(model_production, newdata = future)
)

future$bev_share <- plogis(
  last_bev_logit +
    seq_along(future_dates) * bev_monthly_step
)

future$registrations_bev <- round(
  future$registrations_total_de * future$bev_share
)

future$data_status <- "forecast"

forecast <- future[, c(
  "month",
  "vehicle_production_de",
  "registrations_total_de",
  "registrations_bev",
  "bev_share",
  lag_vars,
  "data_status"
)]

# ---------- Validation ----------
if (anyNA(forecast)) {
  stop("Forecast contains NA values.")
}

if (
  any(forecast$vehicle_production_de <= 0) ||
  any(forecast$registrations_total_de <= 0) ||
  any(forecast$registrations_bev < 0) ||
  any(forecast$registrations_bev > forecast$registrations_total_de)
) {
  stop("Forecast validation failed.")
}

# ---------- Write ----------
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(forecast, output_file, row.names = FALSE)

cat("\nAutomotive forecast Sep-Dec 2026\n")
cat("================================\n")
print(
  forecast[, c(
    "month",
    "vehicle_production_de",
    "registrations_total_de",
    "registrations_bev",
    "bev_share"
  )],
  row.names = FALSE
)

cat("\nRegistration model\n")
cat("==================\n")
cat("Weather lag: 1 month\n")
cat(
  "Adjusted R-squared:",
  round(summary(model_registrations)$adj.r.squared, 3),
  "\n"
)

cat("\nBEV-share path\n")
cat("==============\n")
cat("Method: latest observed share + median recent logit trend\n")

cat("\nWritten to:\n", output_file, "\n")
