import nepali_datetime
import datetime

from calendar_app.models import Event
from organization.models import Organization


def count_saturdays(year: int, month: int, start_day: int = 1, end_day: int | None = None) -> int:
    """
    Counts the number of Saturdays in a given month (or day range) of a specified year
    using the Nepali calendar.
    """
    days_in_month: int = total_days_in_month(year, month)
    resolved_end_day: int = days_in_month if end_day is None else min(end_day, days_in_month)
    start_day = max(1, start_day)
    if start_day > resolved_end_day:
        return 0

    saturdays = sum(1 for day in range(start_day, resolved_end_day + 1)
                    if nepali_datetime.date(year, month, day).weekday() == 6)

    return saturdays


def get_holiday_dates(organization: Organization, year: int, month: int, start_day: int = 1, end_day: int | None = None) -> set:
    """
    Returns the deduplicated set of non-Saturday public holiday (year, month, day) tuples
    in a specific month (or day range) for a given organization.
    Handles single-day, multi-day, overlapping, and cross-month holiday events.
    """
    if not organization:
        return set()

    days_in_month: int = total_days_in_month(year, month)
    resolved_end_day: int = days_in_month if end_day is None else min(end_day, days_in_month)
    start_day = max(1, start_day)
    if start_day > resolved_end_day:
        return set()

    range_start = nepali_datetime.date(year, month, start_day)
    range_end = nepali_datetime.date(year, month, resolved_end_day)

    events = Event.objects.filter(
        organization=organization,
        is_holiday=True,
    ).order_by('start')

    holiday_dates = set()
    for event in events:
        if not event.start:
            continue
        ev_start = event.start
        ev_end = event.end if event.end and event.end >= ev_start else ev_start
        if ev_end < range_start or ev_start > range_end:
            continue
        curr = max(ev_start, range_start)
        clip_end = min(ev_end, range_end)
        while curr <= clip_end:
            # Exclude Saturdays because count_saturdays() already counts all Saturdays.
            # Store (year, month, day) integer tuples because nepali_datetime.date.__hash__
            # returns a non-int on Python 3.13.
            if curr.weekday() != 6:
                holiday_dates.add((curr.year, curr.month, curr.day))
            curr += datetime.timedelta(days=1)

    return holiday_dates


def count_holidays(organization: Organization, year: int, month: int, start_day: int = 1, end_day: int | None = None) -> int:
    """
    Counts the total number of distinct non-Saturday holiday days in a specific month (or day range)
    for a given organization.
    """
    return len(get_holiday_dates(organization, year, month, start_day=start_day, end_day=end_day))


def total_days_in_month(year: int, month: int) -> int:
    """
    Calculates the total number of days in a given month of a specific year.

    Parameters:
        year (int): The year of the month.
        month (int): The month (1-12).

    Returns:
        int: The total number of days in the specified month.
    """
    # Validate year/month bounds first, then look up month length directly so
    # even MAXYEAR-12 works without overflowing into MAXYEAR+1.
    nepali_datetime.date(year, month, 1)
    return int(nepali_datetime._days_in_month(year, month))


def get_events(year: int | None = None, month: int | None = None):
    """
    Returns events in the given month of the year for the given organization.

    Parameters:
        organization: Organization
        year (int): The year of the month.
        month (int): The month (1-12).

    Returns:
        int: The total number of days in the specified month.
    """
    today = nepali_datetime.date.today()
    year = today.year if year is None else year
    month = today.month if month is None else month

    events = Event.objects.all()
    id_list = []
    for event in events:
        if event.start.year == year and event.start.month == month:
            id_list.append(event.id)

    return events.filter(id__in=id_list)


def get_working_days(organization: Organization, year: int | None = None, month: int | None = None) -> int:
    """
    Returns total number of working days in the given 
    month of the year for the given organization.

    Parameters:
        organization: Organization
        year (int): The year of the month.
        month (int): The month (1-12).

    Returns:
        int: The total number of days in the specified month.
    """
    today = nepali_datetime.date.today()
    year = today.year if year is None else year
    month = today.month if month is None else month
    total_days = total_days_in_month(year=year, month=month)
    total_holidays = (count_saturdays(year=year, month=month) +
                      count_holidays(organization=organization, year=year, month=month))

    return total_days - total_holidays
