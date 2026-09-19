# Data contract

## Core inputs

| Path | Grain | Purpose |
|---|---|---|
| `data/master/product_master.csv` | material | Synthetic WKR material master |
| `data/raw/automotive_market_de.csv` | month | Observed German automotive market |
| `data/raw/datumlanderferienfeiertage.csv` | date × state | German calendar/holiday features |
| `data/raw/Wetterbericht MMM.csv` | ISO week | DWD-derived German weather features |
| `data/forecast/automotive_market_de_forecast_2026.csv` | month | Sep–Dec 2026 automotive forecast |
| `data/sales/sales_daily_de.csv` | date × segment | Synthetic German WKR sales; generated locally |

## Calendar output schema

`Datum | Bundesland | Ferien | Karfreitag | Weihnachten | Silvester | ErsterMai | Pfingsten | Himmelfahrt`

The named holiday columns are modelling features around holidays, not simple holiday-date flags. They encode demand/timing effects used in the legacy research-driven calendar logic.

## Powertrain Mounts modelling periods

- Train: 2022-01-01 to 2025-12-31
- Holdout: 2026-01-01 to 2026-08-31
- Forecast: 2026-09-01 to 2026-12-31

The daily grain is intentional. Monthly external drivers may be constant within a month; they are not interpreted as independent daily macro observations.
