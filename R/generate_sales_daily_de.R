# ============================================================
# WKR Komponenten KGaA
# Synthetic German Daily Sales Generator
# Version: 0.3
#
# Purpose:
#   Generate realistic daily German sales for six WKR product
#   segments from 2022-01-01 through 2026-12-31.
#
# Inputs:
#   data/master/product_master.csv
#   data/raw/datumlanderferienfeiertage.csv
#   data/raw/automotive_market_de.csv
#
# Output:
#   data/sales/sales_daily_de.csv
#
# Notes:
#   - Base R only.
#   - v0.3 adds a deliberately simple BEV transformation effect.
#   - BEV share affects OE demand only; Replacement is unchanged.
#   - Non-BEV is the v1 reference group. ice_relevance is used
#     pragmatically as its product-master proxy.
#   - The BEV effect is normalized to the 2024 German BEV share.
#   - No extra BEV elasticity/tuning parameter is introduced.
# ============================================================

set.seed(20260918)


# ------------------------------------------------------------
# 1. Configuration
# ------------------------------------------------------------

ANALYSIS_START <- as.Date("2022-01-01")
ANALYSIS_END   <- as.Date("2026-12-31")

PRODUCT_MASTER_FILE <- "data/master/product_master.csv"
CALENDAR_FILE       <- "data/raw/datumlanderferienfeiertage.csv"
MARKET_FILE         <- "data/raw/automotive_market_de.csv"
OUTPUT_FILE         <- "data/sales/sales_daily_de.csv"

# WKR business scale:
# roughly EUR 1bn global revenue, with Germany historically
# representing around one third of the business.
TARGET_DE_REVENUE_2024 <- 330000000


# ------------------------------------------------------------
# 2. Input checks
# ------------------------------------------------------------

if (!file.exists(PRODUCT_MASTER_FILE)) {
  stop(
    paste0(
      "Product master not found: ",
      PRODUCT_MASTER_FILE,
      "\nRun R/generate_product_master.R first."
    )
  )
}

if (!file.exists(CALENDAR_FILE)) {
  stop(
    paste0(
      "Calendar file not found: ",
      CALENDAR_FILE,
      "\nPlease place datumlanderferienfeiertage.csv in data/raw/."
    )
  )
}

if (!file.exists(MARKET_FILE)) {
  stop(
    paste0(
      "Automotive market file not found: ",
      MARKET_FILE,
      "\nPlease place automotive_market_de.csv in data/raw/."
    )
  )
}


# ------------------------------------------------------------
# 3. Read product master
# ------------------------------------------------------------

product_master <- read.csv(
  PRODUCT_MASTER_FILE,
  stringsAsFactors = FALSE
)

required_product_columns <- c(
  "material_id",
  "segment",
  "sales_channel",
  "ice_relevance",
  "bev_relevance",
  "active_from",
  "active_to"
)

missing_product_columns <- setdiff(
  required_product_columns,
  names(product_master)
)

if (length(missing_product_columns) > 0) {
  stop(
    paste(
      "Missing product master columns:",
      paste(missing_product_columns, collapse = ", ")
    )
  )
}

product_master$active_from <- as.Date(product_master$active_from)
product_master$active_to   <- as.Date(product_master$active_to)


# ------------------------------------------------------------
# 4. Read regional calendar
#
# The source file uses semicolon separators and German dates.
# It covers the Bundeslaender in the WKR historical operating
# region.
# ------------------------------------------------------------

calendar_raw <- read.csv(
  CALENDAR_FILE,
  sep = ";",
  stringsAsFactors = FALSE,
  check.names = FALSE
)

required_calendar_columns <- c(
  "Datum",
  "Bundesland",
  "Ferien",
  "Karfreitag",
  "Weihnachten",
  "Silvester",
  "ErsterMai",
  "Pfingsten",
  "Himmelfahrt"
)

missing_calendar_columns <- setdiff(
  required_calendar_columns,
  names(calendar_raw)
)

if (length(missing_calendar_columns) > 0) {
  stop(
    paste(
      "Missing calendar columns:",
      paste(missing_calendar_columns, collapse = ", ")
    )
  )
}

calendar_raw$Datum <- as.Date(
  calendar_raw$Datum,
  format = "%d.%m.%Y"
)

calendar_raw <- calendar_raw[
  calendar_raw$Datum >= ANALYSIS_START &
    calendar_raw$Datum <= ANALYSIS_END,
]


# ------------------------------------------------------------
# 5. Read observed German automotive market
#
# German passenger-car production drives OE demand.
# v0.3 additionally uses BEV registrations to represent the
# structural shift from the aggregated non-BEV reference group
# toward battery-electric vehicles.
# ------------------------------------------------------------

automotive_market <- read.csv(
  MARKET_FILE,
  stringsAsFactors = FALSE
)

required_market_columns <- c(
  "month",
  "vehicle_production_de",
  "registrations_total_de",
  "registrations_bev"
)

missing_market_columns <- setdiff(
  required_market_columns,
  names(automotive_market)
)

if (length(missing_market_columns) > 0) {
  stop(
    paste(
      "Missing automotive market columns:",
      paste(missing_market_columns, collapse = ", ")
    )
  )
}

automotive_market$month <- as.Date(automotive_market$month)

if (any(is.na(automotive_market$month))) {
  stop("Could not parse one or more dates in automotive_market_de.csv.")
}

if (anyDuplicated(automotive_market$month)) {
  stop("automotive_market_de.csv contains duplicate months.")
}

if (any(is.na(automotive_market$vehicle_production_de)) ||
    any(is.na(automotive_market$registrations_total_de)) ||
    any(is.na(automotive_market$registrations_bev))) {
  stop("Automotive market file contains missing production or registration values.")
}

if (any(automotive_market$vehicle_production_de < 0) ||
    any(automotive_market$registrations_total_de <= 0) ||
    any(automotive_market$registrations_bev < 0)) {
  stop("Automotive market file contains invalid negative/zero market values.")
}

if (any(automotive_market$registrations_bev >
        automotive_market$registrations_total_de)) {
  stop("registrations_bev must not exceed registrations_total_de.")
}

automotive_market$bev_share <-
  automotive_market$registrations_bev /
  automotive_market$registrations_total_de

idx_2024_market <- format(automotive_market$month, "%Y") == "2024"

bev_share_reference_2024 <-
  sum(automotive_market$registrations_bev[idx_2024_market]) /
  sum(automotive_market$registrations_total_de[idx_2024_market])

if (!is.finite(bev_share_reference_2024)) {
  stop("Could not calculate the 2024 BEV-share reference.")
}

# Normalize production around 2024. This preserves the actual
# monthly production pattern while keeping our EUR 330m 2024
# calibration as the WKR business-size anchor.
production_reference_2024 <- mean(
  automotive_market$vehicle_production_de[
    format(automotive_market$month, "%Y") == "2024"
  ]
)

if (is.na(production_reference_2024)) {
  stop("No 2024 production observations found in automotive_market_de.csv.")
}

automotive_market$production_index <-
  automotive_market$vehicle_production_de /
  production_reference_2024


# ------------------------------------------------------------
# 6. Build WKR business calendar
#
# The regional file contains one row per date / Bundesland.
# We aggregate it into a Germany-level WKR calendar signal.
#
# Niedersachsen receives a somewhat larger weight because WKR's
# German footprint historically developed around Volkswagen.
#
# These weights are generator assumptions, not observed facts.
# ------------------------------------------------------------

state_weights <- c(
  "Niedersachsen"      = 0.30,
  "Nordrhein-Westfalen" = 0.20,
  "Brandenburg"        = 0.12,
  "Sachsen-Anhalt"     = 0.12,
  "Thüringen"          = 0.12,
  "Berlin"             = 0.08,
  "Bremen"             = 0.06
)

if (!all(unique(calendar_raw$Bundesland) %in% names(state_weights))) {
  stop("Calendar contains a Bundesland without a WKR state weight.")
}

calendar_raw$state_weight <- state_weights[
  calendar_raw$Bundesland
]

holiday_columns <- c(
  "Karfreitag",
  "Weihnachten",
  "Silvester",
  "ErsterMai",
  "Pfingsten",
  "Himmelfahrt"
)

calendar_raw$holiday_flag <- as.integer(
  rowSums(calendar_raw[, holiday_columns, drop = FALSE]) > 0
)

calendar_dates <- sort(unique(calendar_raw$Datum))

business_calendar <- data.frame(
  date = calendar_dates,
  regional_holiday_intensity = 0,
  school_holiday_intensity = 0,
  stringsAsFactors = FALSE
)

for (i in seq_along(calendar_dates)) {

  d <- calendar_dates[i]

  tmp <- calendar_raw[
    calendar_raw$Datum == d,
  ]

  available_weight <- sum(tmp$state_weight)

  if (available_weight > 0) {

    business_calendar$regional_holiday_intensity[i] <-
      sum(tmp$holiday_flag * tmp$state_weight) /
      available_weight

    business_calendar$school_holiday_intensity[i] <-
      sum(tmp$Ferien * tmp$state_weight) /
      available_weight
  }
}


# ------------------------------------------------------------
# 6. Complete all calendar days
#
# The supplied calendar does not necessarily contain every
# weekend date. Sales must nevertheless contain every calendar
# day, including zero/low-activity days.
# ------------------------------------------------------------

all_dates <- seq(
  ANALYSIS_START,
  ANALYSIS_END,
  by = "day"
)

calendar_complete <- data.frame(
  date = all_dates,
  stringsAsFactors = FALSE
)

calendar_complete <- merge(
  calendar_complete,
  business_calendar,
  by = "date",
  all.x = TRUE,
  sort = TRUE
)

calendar_complete$regional_holiday_intensity[
  is.na(calendar_complete$regional_holiday_intensity)
] <- 0

calendar_complete$school_holiday_intensity[
  is.na(calendar_complete$school_holiday_intensity)
] <- 0


# Attach the observed monthly German production environment to
# each calendar day. Real observations currently end in Aug 2026.
# For Sep-Dec 2026, v0.2 deliberately carries the latest observed
# production level forward only as a temporary generator bridge.
# These months should later be replaced by scenario/forecast values.

calendar_complete$month <- as.Date(
  paste0(
    format(calendar_complete$date, "%Y-%m"),
    "-01"
  )
)

calendar_complete <- merge(
  calendar_complete,
  automotive_market[
    c(
      "month",
      "vehicle_production_de",
      "registrations_total_de",
      "registrations_bev",
      "bev_share",
      "production_index"
    )
  ],
  by = "month",
  all.x = TRUE,
  sort = TRUE
)

last_observed_index <- tail(
  automotive_market$production_index[
    !is.na(automotive_market$production_index)
  ],
  1
)

last_observed_production <- tail(
  automotive_market$vehicle_production_de[
    !is.na(automotive_market$vehicle_production_de)
  ],
  1
)

last_observed_registrations <- tail(
  automotive_market$registrations_total_de[
    !is.na(automotive_market$registrations_total_de)
  ],
  1
)

last_observed_bev <- tail(
  automotive_market$registrations_bev[
    !is.na(automotive_market$registrations_bev)
  ],
  1
)

last_observed_bev_share <- tail(
  automotive_market$bev_share[
    !is.na(automotive_market$bev_share)
  ],
  1
)

calendar_complete$production_index[
  is.na(calendar_complete$production_index)
] <- last_observed_index

calendar_complete$vehicle_production_de[
  is.na(calendar_complete$vehicle_production_de)
] <- last_observed_production

calendar_complete$registrations_total_de[
  is.na(calendar_complete$registrations_total_de)
] <- last_observed_registrations

calendar_complete$registrations_bev[
  is.na(calendar_complete$registrations_bev)
] <- last_observed_bev

calendar_complete$bev_share[
  is.na(calendar_complete$bev_share)
] <- last_observed_bev_share


# ------------------------------------------------------------
# 7. Weekday and shutdown structure
# ------------------------------------------------------------

weekday_number <- as.POSIXlt(calendar_complete$date)$wday
# Sunday = 0, Monday = 1, ..., Saturday = 6

calendar_complete$is_saturday <- as.integer(
  weekday_number == 6
)

calendar_complete$is_sunday <- as.integer(
  weekday_number == 0
)

calendar_complete$is_weekend <- as.integer(
  calendar_complete$is_saturday == 1 |
    calendar_complete$is_sunday == 1
)

month_num <- as.integer(
  format(calendar_complete$date, "%m")
)

day_num <- as.integer(
  format(calendar_complete$date, "%d")
)

# Strong year-end automotive shutdown.
calendar_complete$year_end_shutdown <- as.integer(
  (month_num == 12 & day_num >= 23) |
    (month_num == 1 & day_num <= 2)
)

# Softer summer shutdown signal.
# It is deliberately gradual rather than a complete closure.
calendar_complete$summer_shutdown <- as.integer(
  (month_num == 7 & day_num >= 20) |
    (month_num == 8 & day_num <= 15)
)


# ------------------------------------------------------------
# 8. Working-day weight
#
# This is a hidden generator variable. It is NOT written to the
# final sales dataset.
# ------------------------------------------------------------

calendar_complete$working_day_weight <- 1.00

calendar_complete$working_day_weight[
  calendar_complete$is_saturday == 1
] <- 0.12

calendar_complete$working_day_weight[
  calendar_complete$is_sunday == 1
] <- 0.03

# Regional public holidays reduce activity strongly.
calendar_complete$working_day_weight <-
  calendar_complete$working_day_weight *
  (1 - 0.82 *
     calendar_complete$regional_holiday_intensity)

# School holidays have a much softer operational effect.
calendar_complete$working_day_weight <-
  calendar_complete$working_day_weight *
  (1 - 0.16 *
     calendar_complete$school_holiday_intensity)

# Automotive summer shutdown.
calendar_complete$working_day_weight[
  calendar_complete$summer_shutdown == 1
] <-
  calendar_complete$working_day_weight[
    calendar_complete$summer_shutdown == 1
  ] * 0.62

# Christmas / New Year shutdown dominates other calendar effects.
calendar_complete$working_day_weight[
  calendar_complete$year_end_shutdown == 1
] <-
  pmin(
    calendar_complete$working_day_weight[
      calendar_complete$year_end_shutdown == 1
    ],
    0.06
  )


# ------------------------------------------------------------
# 9. Product-master-derived segment structure
#
# We use the channel composition as a real structural property
# of each segment. The final sales dataset remains segment-level.
# ------------------------------------------------------------

segments <- c(
  "Sealing",
  "Cable Protection",
  "Chassis NVH",
  "Powertrain Mounts",
  "Hoses & Bellows",
  "Other Automotive"
)

channel_share <- data.frame(
  segment = segments,
  oe_share = NA_real_,
  replacement_share = NA_real_,
  both_share = NA_real_,
  stringsAsFactors = FALSE
)

for (i in seq_along(segments)) {

  seg <- segments[i]

  tmp <- product_master[
    product_master$segment == seg,
  ]

  channel_share$oe_share[i] <-
    mean(tmp$sales_channel == "OE")

  channel_share$replacement_share[i] <-
    mean(tmp$sales_channel == "Replacement")

  channel_share$both_share[i] <-
    mean(tmp$sales_channel == "Both")
}

# Segment-level relative BEV content proxy.
#
# v1 intentionally distinguishes only BEV vs. non-BEV. The
# existing ice_relevance is used as a pragmatic proxy for the
# aggregated non-BEV reference group. No additional elasticity
# is introduced: a ratio of 1 is neutral, below 1 is lower BEV
# content, and above 1 is higher BEV content.
segment_relevance <- aggregate(
  cbind(ice_relevance, bev_relevance) ~ segment,
  data = product_master,
  FUN = mean
)

if (any(segment_relevance$ice_relevance <= 0)) {
  stop("Mean segment ice_relevance must be greater than zero.")
}

segment_relevance$bev_to_non_bev_ratio <-
  segment_relevance$bev_relevance /
  segment_relevance$ice_relevance


# ------------------------------------------------------------
# 10. Segment economics
#
# Revenue shares define WKR Germany's approximate business mix.
# Average unit values are deliberately very different across
# segments: an O-ring is not economically comparable with a
# powertrain mount.
#
# These are synthetic generator assumptions.
# ------------------------------------------------------------

segment_economics <- data.frame(
  segment = segments,

  revenue_share = c(
    0.20,  # Sealing
    0.11,  # Cable Protection
    0.21,  # Chassis NVH
    0.22,  # Powertrain Mounts
    0.18,  # Hoses & Bellows
    0.08   # Other Automotive
  ),

  avg_unit_value_eur = c(
    3.20,
    6.50,
    24.00,
    58.00,
    15.00,
    9.00
  ),

  # Small underlying annual trend for v0.1 only.
  annual_trend = c(
     0.010,
     0.025,
     0.008,
    -0.018,
     0.006,
     0.004
  ),

  stringsAsFactors = FALSE
)

stopifnot(
  abs(sum(segment_economics$revenue_share) - 1) < 1e-10
)

segment_economics <- merge(
  segment_economics,
  channel_share,
  by = "segment",
  sort = FALSE
)

segment_economics <- merge(
  segment_economics,
  segment_relevance[c("segment", "bev_to_non_bev_ratio")],
  by = "segment",
  sort = FALSE
)


# ------------------------------------------------------------
# 11. Daily weekday pattern
#
# Even among weekdays, automotive shipments are not perfectly
# flat. Friday is slightly softer.
# ------------------------------------------------------------

weekday_factor <- c(
  "0" = 1.00,  # Sunday already handled by working-day weight
  "1" = 0.98,  # Monday
  "2" = 1.03,  # Tuesday
  "3" = 1.04,  # Wednesday
  "4" = 1.02,  # Thursday
  "5" = 0.93,  # Friday
  "6" = 1.00   # Saturday already handled
)

calendar_complete$weekday_factor <-
  weekday_factor[
    as.character(
      as.POSIXlt(calendar_complete$date)$wday
    )
  ]

calendar_complete$weekday_factor <-
  as.numeric(calendar_complete$weekday_factor)


# ------------------------------------------------------------
# 12. Generate latent daily demand by segment
# ------------------------------------------------------------

sales_list <- vector(
  "list",
  length(segments)
)

for (s in seq_along(segments)) {

  seg <- segments[s]

  econ <- segment_economics[
    segment_economics$segment == seg,
  ]

  n_days <- nrow(calendar_complete)

  years_from_2024 <- as.numeric(
    calendar_complete$date - as.Date("2024-01-01")
  ) / 365.25

  trend_factor <- (
    1 + econ$annual_trend
  ) ^ years_from_2024

  # Replacement-oriented segments are less sensitive to the
  # production calendar than OE-heavy segments.
  effective_oe_exposure <-
    econ$oe_share + 0.50 * econ$both_share

  effective_replacement_exposure <-
    econ$replacement_share + 0.50 * econ$both_share

  # German vehicle production is the first observed external
  # driver in the DGP. OE business reacts substantially; the
  # replacement component is intentionally much less exposed.
  #
  # The exponent below gives a slightly damped response rather
  # than assuming a mechanically one-for-one relationship.
  oe_market_factor <-
    calendar_complete$production_index ^ 0.78

  replacement_market_factor <-
    calendar_complete$production_index ^ 0.10

  # BEV transformation: weighted content per vehicle relative to
  # the 2024 German drivetrain mix. All non-BEV registrations are
  # intentionally treated as one reference group in v1.
  #
  # content_index = (1 - BEV share) * 1 +
  #                 BEV share * BEV/non-BEV content ratio
  #
  # The factor is applied to OE only. Replacement is left
  # untouched because current new registrations do not describe
  # the installed vehicle fleet.
  bev_content_index <-
    1 +
    calendar_complete$bev_share *
      (econ$bev_to_non_bev_ratio - 1)

  bev_content_reference_2024 <-
    1 +
    bev_share_reference_2024 *
      (econ$bev_to_non_bev_ratio - 1)

  oe_bev_factor <-
    bev_content_index / bev_content_reference_2024

  calendar_factor <-
    effective_oe_exposure *
      calendar_complete$working_day_weight *
      oe_market_factor *
      oe_bev_factor +
    effective_replacement_exposure *
      (
        0.45 +
          0.55 * calendar_complete$working_day_weight
      ) *
      replacement_market_factor

  # Gentle annual seasonality. This is intentionally small;
  # the business calendar carries most of the daily structure.
  day_of_year <- as.integer(
    format(calendar_complete$date, "%j")
  )

  seasonal_factor <-
    1 +
    0.035 * sin(
      2 * pi * (day_of_year - 35) / 365.25
    ) +
    0.018 * cos(
      4 * pi * day_of_year / 365.25
    )

  # Persistent short-term business variation:
  # an AR(1)-like process rather than independent white noise.
  shock <- numeric(n_days)
  innovations <- rnorm(n_days, mean = 0, sd = 0.035)

  for (t in 2:n_days) {
    shock[t] <- 0.68 * shock[t - 1] + innovations[t]
  }

  short_term_factor <- exp(shock)

  raw_demand_index <-
    trend_factor *
    calendar_factor *
    calendar_complete$weekday_factor *
    seasonal_factor *
    short_term_factor

  sales_list[[s]] <- data.frame(
    date = calendar_complete$date,
    segment = seg,
    raw_demand_index = raw_demand_index,
    avg_unit_value_eur = econ$avg_unit_value_eur,
    stringsAsFactors = FALSE
  )
}

sales_latent <- do.call(
  rbind,
  sales_list
)


# ------------------------------------------------------------
# 13. Calibrate to EUR 330m German revenue in 2024
#
# Calibration is done at segment level so the 2024 business mix
# approximately matches the configured revenue shares.
# ------------------------------------------------------------

sales_latent$target_segment_revenue_2024 <- NA_real_

for (seg in segments) {

  idx <- sales_latent$segment == seg

  share <- segment_economics$revenue_share[
    segment_economics$segment == seg
  ]

  target <- TARGET_DE_REVENUE_2024 * share

  idx_2024 <- idx &
    format(sales_latent$date, "%Y") == "2024"

  raw_sum_2024 <- sum(
    sales_latent$raw_demand_index[idx_2024]
  )

  scale_factor <- target / raw_sum_2024

  sales_latent$target_segment_revenue_2024[idx] <-
    scale_factor
}


# ------------------------------------------------------------
# 14. Generate units and net sales
#
# Units are generated from implied segment revenue and average
# unit value. Net sales then contain modest daily price/mix
# variation around the segment average.
# ------------------------------------------------------------

expected_revenue <-
  sales_latent$raw_demand_index *
  sales_latent$target_segment_revenue_2024

expected_units <-
  expected_revenue /
  sales_latent$avg_unit_value_eur

# Count variation is small relative to the high daily volumes.
# rpois keeps units integer and non-negative.
sales_latent$units <- rpois(
  nrow(sales_latent),
  lambda = pmax(expected_units, 0)
)

price_mix_factor <- exp(
  rnorm(
    nrow(sales_latent),
    mean = -0.5 * 0.018^2,
    sd = 0.018
  )
)

sales_latent$net_sales_eur <- round(
  sales_latent$units *
    sales_latent$avg_unit_value_eur *
    price_mix_factor,
  2
)


# ------------------------------------------------------------
# 15. Final visible sales table
# ------------------------------------------------------------

sales_daily_de <- sales_latent[
  c(
    "date",
    "segment",
    "units",
    "net_sales_eur"
  )
]

sales_daily_de <- sales_daily_de[
  order(
    sales_daily_de$date,
    sales_daily_de$segment
  ),
]

row.names(sales_daily_de) <- NULL


# ------------------------------------------------------------
# 16. Validation
# ------------------------------------------------------------

expected_days <- length(
  seq(ANALYSIS_START, ANALYSIS_END, by = "day")
)

stopifnot(
  nrow(sales_daily_de) ==
    expected_days * length(segments)
)

stopifnot(
  !any(is.na(sales_daily_de))
)

stopifnot(
  all(sales_daily_de$units >= 0)
)

stopifnot(
  all(sales_daily_de$net_sales_eur >= 0)
)

stopifnot(
  length(unique(sales_daily_de$segment)) ==
    length(segments)
)


# ------------------------------------------------------------
# 17. Write output
# ------------------------------------------------------------

dir.create(
  dirname(OUTPUT_FILE),
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  sales_daily_de,
  OUTPUT_FILE,
  row.names = FALSE
)


# ------------------------------------------------------------
# 18. Inspection
# ------------------------------------------------------------

cat("\nWKR German Daily Sales v0.3 generated\n")
cat("------------------------------------\n")
cat("Rows:", nrow(sales_daily_de), "\n")
cat(
  "Period:",
  as.character(min(sales_daily_de$date)),
  "to",
  as.character(max(sales_daily_de$date)),
  "\n\n"
)

sales_daily_de$year <- format(
  sales_daily_de$date,
  "%Y"
)

annual_sales <- aggregate(
  net_sales_eur ~ year,
  data = sales_daily_de,
  FUN = sum
)

annual_sales$net_sales_m_eur <- round(
  annual_sales$net_sales_eur / 1000000,
  1
)

cat("German annual net sales (EUR m):\n")
print(
  annual_sales[
    c("year", "net_sales_m_eur")
  ],
  row.names = FALSE
)

sales_2024 <- sales_daily_de[
  sales_daily_de$year == "2024",
]

segment_sales_2024 <- aggregate(
  net_sales_eur ~ segment,
  data = sales_2024,
  FUN = sum
)

segment_sales_2024$net_sales_m_eur <- round(
  segment_sales_2024$net_sales_eur / 1000000,
  1
)

segment_sales_2024$share_pct <- round(
  100 *
    segment_sales_2024$net_sales_eur /
    sum(segment_sales_2024$net_sales_eur),
  1
)

cat("\n2024 sales by segment:\n")
print(
  segment_sales_2024[
    c(
      "segment",
      "net_sales_m_eur",
      "share_pct"
    )
  ],
  row.names = FALSE
)

cat("\nBEV transformation assumptions by segment:\n")
bev_inspection <- segment_relevance[
  match(segments, segment_relevance$segment),
  c(
    "segment",
    "ice_relevance",
    "bev_relevance",
    "bev_to_non_bev_ratio"
  )
]
bev_inspection$ice_relevance <- round(bev_inspection$ice_relevance, 3)
bev_inspection$bev_relevance <- round(bev_inspection$bev_relevance, 3)
bev_inspection$bev_to_non_bev_ratio <-
  round(bev_inspection$bev_to_non_bev_ratio, 3)
print(bev_inspection, row.names = FALSE)

cat(
  "\n2024 BEV-share reference:",
  round(100 * bev_share_reference_2024, 2),
  "%\n"
)

cat("\nRandom daily observations:\n")

print(
  sales_daily_de[
    sample(seq_len(nrow(sales_daily_de)), 12),
    c(
      "date",
      "segment",
      "units",
      "net_sales_eur"
    )
  ],
  row.names = FALSE
)
