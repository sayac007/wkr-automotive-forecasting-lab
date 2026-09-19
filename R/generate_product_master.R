# ============================================================
# WKR Komponenten KGaA
# Synthetic Product Master Generator
# Version: 0.3
# ============================================================

set.seed(20260918)

N_PRODUCTS <- 24000


# ------------------------------------------------------------
# 1. Segment structure
# ------------------------------------------------------------

segments <- data.frame(
  segment = c(
    "Sealing",
    "Cable Protection",
    "Chassis NVH",
    "Powertrain Mounts",
    "Hoses & Bellows",
    "Other Automotive"
  ),
  n_products = c(6200, 3100, 4800, 3600, 4100, 2200),
  stringsAsFactors = FALSE
)

stopifnot(sum(segments$n_products) == N_PRODUCTS)


# ------------------------------------------------------------
# 2. Product descriptions
# ------------------------------------------------------------

descriptions <- list(
  "Sealing" = c(
    "Form seal", "O-ring", "Shaft seal",
    "Housing seal", "Flange seal", "Profile seal"
  ),
  "Cable Protection" = c(
    "Cable grommet", "Protective sleeve", "Cable boot",
    "Connector seal", "Cable pass-through", "Protective bellows"
  ),
  "Chassis NVH" = c(
    "Control arm bushing", "Stabilizer bushing", "Axle bushing",
    "Strut mount", "Suspension isolator", "Vibration damper"
  ),
  "Powertrain Mounts" = c(
    "Engine mount", "Transmission mount", "Torque mount",
    "Powertrain isolator", "Mounting bushing"
  ),
  "Hoses & Bellows" = c(
    "Coolant hose", "Air hose", "Protective boot",
    "CV boot", "Flexible hose", "Rubber bellows"
  ),
  "Other Automotive" = c(
    "Elastomer buffer", "Rubber pad", "Vibration isolator",
    "Protective cap", "Moulded rubber part",
    "Special elastomer component"
  )
)


# ------------------------------------------------------------
# 3. Generate portfolio
# ------------------------------------------------------------

product_master <- do.call(
  rbind,
  lapply(seq_len(nrow(segments)), function(i) {
    seg <- segments$segment[i]
    n <- segments$n_products[i]

    data.frame(
      segment = rep(seg, n),
      product_description = sample(
        descriptions[[seg]], n, replace = TRUE
      ),
      stringsAsFactors = FALSE
    )
  })
)


# ------------------------------------------------------------
# 4. Material IDs
# ------------------------------------------------------------

product_master$material_id <- sprintf(
  "WKR-%08d",
  sample(10000000:99999999, N_PRODUCTS)
)


# ------------------------------------------------------------
# 5. Segment-specific sales channels
# ------------------------------------------------------------

channel_prob <- list(
  "Sealing" =
    c(OE = 0.65, Replacement = 0.10, Both = 0.25),
  "Cable Protection" =
    c(OE = 0.75, Replacement = 0.05, Both = 0.20),
  "Chassis NVH" =
    c(OE = 0.35, Replacement = 0.25, Both = 0.40),
  "Powertrain Mounts" =
    c(OE = 0.40, Replacement = 0.20, Both = 0.40),
  "Hoses & Bellows" =
    c(OE = 0.35, Replacement = 0.30, Both = 0.35),
  "Other Automotive" =
    c(OE = 0.55, Replacement = 0.15, Both = 0.30)
)

product_master$sales_channel <- vapply(
  product_master$segment,
  function(seg) {
    p <- channel_prob[[seg]]
    sample(names(p), size = 1, prob = p)
  },
  character(1)
)


# ------------------------------------------------------------
# 6. Drivetrain relevance
# ------------------------------------------------------------

product_master$ice_relevance  <- NA_real_
product_master$hev_relevance  <- NA_real_
product_master$phev_relevance <- NA_real_
product_master$bev_relevance  <- NA_real_

for (i in seq_len(N_PRODUCTS)) {

  seg <- product_master$segment[i]

  if (seg == "Powertrain Mounts") {

    product_master$ice_relevance[i] <-
      sample(c(0.75, 1.00), 1, prob = c(0.25, 0.75))

    product_master$hev_relevance[i] <-
      sample(c(0.50, 0.75, 1.00), 1,
             prob = c(0.15, 0.45, 0.40))

    product_master$phev_relevance[i] <-
      sample(c(0.50, 0.75, 1.00), 1,
             prob = c(0.25, 0.50, 0.25))

    product_master$bev_relevance[i] <-
      sample(c(0, 0.25, 0.50, 0.75), 1,
             prob = c(0.40, 0.30, 0.20, 0.10))

  } else if (seg == "Cable Protection") {

    product_master$ice_relevance[i] <-
      sample(c(0.50, 0.75, 1.00), 1,
             prob = c(0.15, 0.40, 0.45))

    product_master$hev_relevance[i] <-
      sample(c(0.75, 1.00), 1, prob = c(0.30, 0.70))

    product_master$phev_relevance[i] <-
      sample(c(0.75, 1.00), 1, prob = c(0.25, 0.75))

    product_master$bev_relevance[i] <-
      sample(c(0.75, 1.00), 1, prob = c(0.20, 0.80))

  } else if (seg == "Chassis NVH") {

    base <- sample(
      c(0.75, 1.00), 1, prob = c(0.20, 0.80)
    )

    product_master$ice_relevance[i]  <- base
    product_master$hev_relevance[i]  <- base
    product_master$phev_relevance[i] <- base
    product_master$bev_relevance[i]  <- base

  } else {

    product_master$ice_relevance[i] <- sample(
      c(0.25, 0.50, 0.75, 1.00), 1,
      prob = c(0.05, 0.10, 0.25, 0.60)
    )

    product_master$hev_relevance[i] <- sample(
      c(0.25, 0.50, 0.75, 1.00), 1,
      prob = c(0.04, 0.10, 0.26, 0.60)
    )

    product_master$phev_relevance[i] <- sample(
      c(0.25, 0.50, 0.75, 1.00), 1,
      prob = c(0.05, 0.12, 0.28, 0.55)
    )

    product_master$bev_relevance[i] <- sample(
      c(0, 0.25, 0.50, 0.75, 1.00), 1,
      prob = c(0.08, 0.08, 0.14, 0.25, 0.45)
    )
  }
}


# ------------------------------------------------------------
# 7. Product lifecycle - v0.3
#
# Lifecycle is generated in months.
# Every material is active at least once during 2022-2026.
# ------------------------------------------------------------

analysis_start <- as.Date("2022-01-01")
analysis_end   <- as.Date("2026-12-31")

product_master$active_from <- as.Date(NA)
product_master$active_to   <- as.Date(NA)

possible_starts_all <- seq(
  as.Date("2005-01-01"),
  as.Date("2026-09-01"),
  by = "month"
)

add_months <- function(date, n_months) {
  lt <- as.POSIXlt(date)
  lt$mon <- lt$mon + n_months
  as.Date(lt)
}

for (i in seq_len(N_PRODUCTS)) {

  channel <- product_master$sales_channel[i]

  if (channel == "OE") {
    life_months <- sample(60:108, 1)

  } else if (channel == "Replacement") {
    life_months <- sample(120:240, 1)

  } else {
    life_months <- sample(96:192, 1)
  }

  end_candidates <- vapply(
    possible_starts_all,
    function(d) {
      as.numeric(add_months(as.Date(d, origin = "1970-01-01"),
                            life_months) - 1)
    },
    numeric(1)
  )

  end_candidates <- as.Date(
    end_candidates,
    origin = "1970-01-01"
  )

  # A material must overlap the 2022-2026 analysis window.
  valid <- (
    end_candidates >= analysis_start &
    possible_starts_all <= analysis_end
  )

  possible_starts <- possible_starts_all[valid]

  active_from <- sample(possible_starts, 1)
  lifecycle_end <- add_months(active_from, life_months) - 1

  product_master$active_from[i] <- active_from

  # Products extending beyond the analysis horizon are
  # represented as currently active.
  if (lifecycle_end > analysis_end) {
    product_master$active_to[i] <- as.Date(NA)
  } else {
    product_master$active_to[i] <- lifecycle_end
  }
}


# ------------------------------------------------------------
# 8. Column order
# ------------------------------------------------------------

product_master <- product_master[
  c(
    "material_id",
    "segment",
    "product_description",
    "sales_channel",
    "ice_relevance",
    "hev_relevance",
    "phev_relevance",
    "bev_relevance",
    "active_from",
    "active_to"
  )
]


# ------------------------------------------------------------
# 9. Validation
# ------------------------------------------------------------

stopifnot(nrow(product_master) == N_PRODUCTS)

stopifnot(
  length(unique(product_master$material_id)) == N_PRODUCTS
)

stopifnot(
  !any(is.na(product_master$segment))
)

stopifnot(
  !any(product_master$active_from > analysis_end)
)

stopifnot(
  !any(
    !is.na(product_master$active_to) &
      product_master$active_to < analysis_start
  )
)


# ------------------------------------------------------------
# 10. Output
# ------------------------------------------------------------

dir.create(
  "data/master",
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  product_master,
  "data/master/product_master.csv",
  row.names = FALSE,
  na = ""
)


# ------------------------------------------------------------
# 11. Inspection
# ------------------------------------------------------------

cat("\nWKR Product Master v0.3 generated\n")
cat("---------------------------------\n")
cat("Products:", nrow(product_master), "\n\n")

cat("Segment x Sales Channel:\n")
print(
  addmargins(
    table(
      product_master$segment,
      product_master$sales_channel
    )
  )
)

cat("\nLifecycle:\n")

cat(
  "Earliest active_from:",
  as.character(min(product_master$active_from)),
  "\n"
)

cat(
  "Active beyond 2026:",
  sum(is.na(product_master$active_to)),
  "\n"
)

cat(
  "Ended during 2022-2026:",
  sum(!is.na(product_master$active_to)),
  "\n"
)

cat("\nLifecycle summary:\n")
print(summary(product_master$active_from))
print(table(is.na(product_master$active_to)))

cat("\nRandom lifecycle sample:\n")

print(
  product_master[
    sample(seq_len(N_PRODUCTS), 10),
    c(
      "material_id",
      "segment",
      "sales_channel",
      "active_from",
      "active_to"
    )
  ]
)
