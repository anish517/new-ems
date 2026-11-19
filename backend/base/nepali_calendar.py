"""Canonical Bikram Sambat (B.S.) calendar synchronization for `nepali_datetime`.

`nepali-datetime==1.0.8.2` ships outdated projected month lengths for BS
2082-2100 (for instance, Asoj 2083 = 30 instead of 31 and Mangsir 2083 = 30
instead of 29). Because the Flutter frontend (`nepali_utils`) uses the official
BS month lengths, backend-computed dates were off by +1 day from Asoj 31
through Mangsir 29 and diverged further in later years.

Calling `patch_nepali_datetime()` from `base/__init__.py` guarantees that every
Django entrypoint (gunicorn, manage.py, tests, scheduled reminders) loads the
exact same BS calendar table as the frontend before any app imports
`nepali_datetime`.
"""

import csv
import datetime as _dt
from pathlib import Path

import nepali_datetime
import nepali_datetime.config as _nepali_config

CALENDAR_CSV_PATH = Path(__file__).resolve().parent / "calendar_bs.csv"
_PATCHED = False


def patch_nepali_datetime(csv_path: Path = CALENDAR_CSV_PATH, force: bool = False) -> None:
    """Replace `nepali_datetime`'s in-memory calendar table with `calendar_bs.csv`."""
    global _PATCHED
    if _PATCHED and not force:
        return

    new_calendar = {}
    new_days_before_year = []
    expected_year = nepali_datetime.MINYEAR
    cumulative_days = 0
    last_year = None
    last_months = None

    with open(csv_path, "r", encoding="utf-8", newline="") as calendar_file:
        reader = csv.reader(calendar_file)
        next(reader)  # skip header row
        for row in reader:
            if not row:
                continue
            year = int(row[0])
            months = [int(v) for v in row[1:]]
            if year != expected_year:
                raise ValueError(
                    f"Non-contiguous BS calendar year in {csv_path}: "
                    f"expected {expected_year}, got {year}"
                )
            if len(months) != 12 or any(not (28 <= d <= 32) for d in months):
                raise ValueError(f"Invalid month lengths for BS {year}: {months}")

            new_calendar[year] = [-1, *[sum(months[:i]) for i in range(1, 13)]]
            cumulative_days += sum(months)
            new_days_before_year.append(cumulative_days)

            last_year = year
            last_months = months
            expected_year += 1

    if last_year is None or last_months is None:
        raise ValueError(f"BS calendar file {csv_path} is empty")

    # Mutate module containers in-place so all internal helpers immediately see
    # the updated data regardless of import order.
    nepali_datetime._CALENDAR.clear()
    nepali_datetime._CALENDAR.update(new_calendar)
    nepali_datetime._DAYS_BEFORE_YEAR[:] = new_days_before_year
    nepali_datetime._MAXORDINAL = new_days_before_year[-1]

    max_day = last_months[-1]
    nepali_datetime.MAXYEAR = last_year
    nepali_datetime.MAXDATE = {"year": last_year, "month": 12, "day": max_day}
    _nepali_config.MAXDATE = dict(nepali_datetime.MAXDATE)
    nepali_datetime.CALENDAR_PATH = str(csv_path)
    _nepali_config.CALENDAR_PATH = str(csv_path)

    nepali_datetime.date.max = nepali_datetime.date(last_year, 12, max_day)
    nepali_datetime.datetime.max = nepali_datetime.datetime(
        last_year, 12, max_day, 23, 59, 59, 999999
    )
    nepali_datetime._EPOCH_BS = nepali_datetime.datetime.from_datetime_datetime(
        _dt.datetime(1970, 1, 1, tzinfo=_dt.timezone.utc)
    )
    _PATCHED = True
