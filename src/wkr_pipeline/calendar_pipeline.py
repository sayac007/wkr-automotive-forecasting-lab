#!/usr/bin/env python3
"""
Build WKR's German calendar table reproducibly from external calendar data.

Source:
  OpenHolidays API for school holidays and public holidays.
  The API's German school-holiday data covers the historical period needed by WKR.
  KMK remains the authoritative validation source for German school holidays.

Output schema intentionally matches the existing WKR file:
Datum;Bundesland;Ferien;Karfreitag;Weihnachten;Silvester;ErsterMai;Pfingsten;Himmelfahrt

Important business semantics:
- Rows represent potential selling/working days: Sundays and public holidays are omitted.
- Ferien marks school-holiday days.
- The other columns are NOT holiday flags. They are demand/timing features around holidays,
  preserving the research-driven convention used in the legacy WKR input.
"""

from __future__ import annotations
import argparse
import csv
import json
import logging
import sys
import time
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta
from pathlib import Path

LOG = logging.getLogger("wkr.calendar")

STATES = {
    "Berlin": "DE-BE",
    "Brandenburg": "DE-BB",
    "Bremen": "DE-HB",
    "Niedersachsen": "DE-NI",
    "Nordrhein-Westfalen": "DE-NW",
    "Sachsen-Anhalt": "DE-ST",
    "Thüringen": "DE-TH",
}

COLUMNS = [
    "Datum", "Bundesland", "Ferien", "Karfreitag", "Weihnachten",
    "Silvester", "ErsterMai", "Pfingsten", "Himmelfahrt",
]

API_BASE = "https://openholidaysapi.org"


def easter_sunday(year: int) -> date:
    """Gregorian Easter, Meeus/Jones/Butcher algorithm."""
    a = year % 19
    b, c = divmod(year, 100)
    d, e = divmod(b, 4)
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = divmod(c, 4)
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month = (h + l - 7 * m + 114) // 31
    day = (h + l - 7 * m + 114) % 31 + 1
    return date(year, month, day)


def get_json(path: str, params: dict[str, str], retries: int = 4) -> list[dict]:
    url = f"{API_BASE}{path}?{urllib.parse.urlencode(params)}"
    last_error = None
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(
                url,
                headers={"Accept": "text/json", "User-Agent": "wkr-automotive-forecasting-lab/1.0"},
            )
            with urllib.request.urlopen(req, timeout=30) as response:
                if response.status != 200:
                    raise RuntimeError(f"HTTP {response.status}: {url}")
                return json.loads(response.read().decode("utf-8"))
        except Exception as exc:
            last_error = exc
            LOG.warning("API attempt %s/%s failed: %s", attempt, retries, exc)
            if attempt < retries:
                time.sleep(2 ** (attempt - 1))
    raise RuntimeError(f"Could not retrieve {url}") from last_error


def fetch_periods(endpoint: str, subdivision: str, start: date, end: date) -> list[dict]:
    # OpenHolidays limits one query to <= 3 years. Query by calendar year for transparent caching.
    all_rows: list[dict] = []
    for year in range(start.year, end.year + 1):
        a = max(start, date(year, 1, 1))
        b = min(end, date(year, 12, 31))
        rows = get_json(
            endpoint,
            {
                "countryIsoCode": "DE",
                "subdivisionCode": subdivision,
                "languageIsoCode": "DE",
                "validFrom": a.isoformat(),
                "validTo": b.isoformat(),
            },
        )
        all_rows.extend(rows)
    return all_rows


def expand_periods(periods: list[dict], start: date, end: date) -> set[date]:
    result: set[date] = set()
    for item in periods:
        a = date.fromisoformat(item["startDate"][:10])
        b = date.fromisoformat(item["endDate"][:10])
        cur = max(a, start)
        stop = min(b, end)
        while cur <= stop:
            result.add(cur)
            cur += timedelta(days=1)
    return result


def previous_non_sunday(day: date) -> date:
    d = day - timedelta(days=1)
    while d.weekday() == 6:
        d -= timedelta(days=1)
    return d


def demand_feature_dates(year: int) -> dict[str, set[date]]:
    """
    Research-driven timing features used in the legacy file.

    Christmas is generated consistently as 24 Dec (or the preceding Saturday if 24 Dec is Sunday).
    The legacy file contains three isolated deviations (2019, 2025, 2026: 23 Dec);
    these are treated as legacy/manual differences rather than copied into the new generator.
    """
    easter = easter_sunday(year)
    good_friday = easter - timedelta(days=2)
    return {
        "Karfreitag": {good_friday - timedelta(days=1), good_friday + timedelta(days=1)},
        "Weihnachten": {date(year, 12, 24) if date(year, 12, 24).weekday() != 6 else date(year, 12, 23)},
        "Silvester": {date(year, 12, 31) if date(year, 12, 31).weekday() != 6 else date(year, 12, 30)},
        "ErsterMai": {previous_non_sunday(date(year, 5, 1))},
        "Pfingsten": {easter + timedelta(days=48)},      # Saturday before Whit Monday
        "Himmelfahrt": {easter + timedelta(days=38)},   # Wednesday before Ascension
    }


def build_calendar(start: date, end: date) -> list[dict]:
    rows: list[dict] = []
    for state_name, subdivision in STATES.items():
        LOG.info("Fetching %s", state_name)
        school = expand_periods(fetch_periods("/SchoolHolidays", subdivision, start, end), start, end)
        public = expand_periods(fetch_periods("/PublicHolidays", subdivision, start, end), start, end)

        features = {}
        for year in range(start.year, end.year + 1):
            for name, dates in demand_feature_dates(year).items():
                features.setdefault(name, set()).update(dates)

        cur = start
        while cur <= end:
            # Match legacy grain: Sunday and actual public holidays are not selling/working rows.
            if cur.weekday() != 6 and cur not in public:
                row = {
                    "Datum": cur.strftime("%d.%m.%Y"),
                    "Bundesland": state_name,
                    "Ferien": int(cur in school),
                }
                for name in COLUMNS[3:]:
                    row[name] = int(cur in features[name])
                rows.append(row)
            cur += timedelta(days=1)
    return rows


def validate(rows: list[dict], start: date, end: date) -> None:
    if not rows:
        raise ValueError("Calendar is empty.")
    keys = [(r["Datum"], r["Bundesland"]) for r in rows]
    if len(keys) != len(set(keys)):
        raise ValueError("Duplicate (Datum, Bundesland) rows.")
    states = {r["Bundesland"] for r in rows}
    if states != set(STATES):
        raise ValueError(f"Unexpected states: {states}")
    for r in rows:
        for col in COLUMNS[2:]:
            if r[col] not in (0, 1):
                raise ValueError(f"{col} is not binary: {r}")
    LOG.info("Validated %s rows, %s to %s.", len(rows), start, end)


def read_legacy(path: Path) -> dict[tuple[str, str], dict]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f, delimiter=";")
        return {(r["Datum"], r["Bundesland"]): r for r in reader}


def compare(rows: list[dict], legacy_path: Path, output_dir: Path) -> dict:
    legacy = read_legacy(legacy_path)
    generated = {(r["Datum"], r["Bundesland"]): r for r in rows}
    common = sorted(set(legacy) & set(generated))
    details = []
    summary = {"generated_rows": len(generated), "legacy_rows": len(legacy), "common_rows": len(common)}

    for col in COLUMNS[2:]:
        matches = 0
        mismatches = 0
        for key in common:
            old = int(legacy[key][col])
            new = int(generated[key][col])
            if old == new:
                matches += 1
            else:
                mismatches += 1
                details.append({
                    "Datum": key[0], "Bundesland": key[1], "Variable": col,
                    "Legacy": old, "Generated": new,
                })
        summary[col] = {
            "matches": matches,
            "mismatches": mismatches,
            "match_rate": matches / len(common) if common else None,
        }

    summary["legacy_only_rows"] = len(set(legacy) - set(generated))
    summary["generated_only_rows"] = len(set(generated) - set(legacy))

    output_dir.mkdir(parents=True, exist_ok=True)
    with (output_dir / "calendar_comparison_summary.json").open("w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)
    with (output_dir / "calendar_comparison_mismatches.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["Datum", "Bundesland", "Variable", "Legacy", "Generated"], delimiter=";")
        writer.writeheader()
        writer.writerows(details)
    return summary


def write_calendar(rows: list[dict], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=COLUMNS, delimiter=";")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--start-year", type=int, default=2017)
    parser.add_argument("--end-year", type=int, default=2026)
    parser.add_argument("--output", type=Path, default=Path("outputs/datumlanderferienfeiertage.csv"))
    parser.add_argument("--legacy", type=Path, default=None)
    parser.add_argument("--comparison-dir", type=Path, default=Path("outputs"))
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    if args.start_year > args.end_year:
        raise ValueError("start-year must be <= end-year")

    start = date(args.start_year, 1, 1)
    end = date(args.end_year, 12, 31)
    rows = build_calendar(start, end)
    validate(rows, start, end)
    write_calendar(rows, args.output)
    LOG.info("Wrote %s", args.output)

    if args.legacy:
        summary = compare(rows, args.legacy, args.comparison_dir)
        LOG.info("Comparison: %s", json.dumps(summary, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    sys.exit(main())
