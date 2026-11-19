import nepali_datetime
import datetime

from calendar_app.models import Event
from organization.models import Organization


def count_saturdays(year: int, month: int, start_day: int = 1, end_day: int = None) -> int:
    """
    Counts the number of Saturdays in a given month (or day range) of a specified year
    using the Nepali calendar.
    """
    days_in_month = total_days_in_month(year, month)
    if end_day is None or end_day > days_in_month:
        end_day = days_in_month
    start_day = max(1, start_day)
    if start_day > end_day:
        return 0

    saturdays = sum(1 for day in range(start_day, end_day + 1)
                    if nepali_datetime.date(year, month, day).weekday() == 6)

    return saturdays


def count_holidays(organization: Organization, year: int, month: int, start_day: int = 1, end_day: int = None) -> int:
    """
    Counts the total number of holiday days in a specific month (or day range) for a given organization.
    """
    if not organization:
        return 0

    days_in_month = total_days_in_month(year, month)
    if end_day is None or end_day > days_in_month:
        end_day = days_in_month
    start_day = max(1, start_day)
    if start_day > end_day:
        return 0

    events = Event.objects.filter(
        organization=organization,
        is_holiday=True,
    ).order_by('start')

    holidays = 0

    for event in events:
        if event.start.year == year and event.start.month == month:
            ev_start = event.start.day
            ev_end = ev_start + event.duration - 1
            overlap_start = max(start_day, ev_start)
            overlap_end = min(end_day, ev_end)
            if overlap_start <= overlap_end:
                holidays += (overlap_end - overlap_start + 1)

    return holidays


def total_days_in_month(year: int, month: int):
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
    return nepali_datetime._days_in_month(year, month)


def get_events(year: int = None, month: int = None):
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


def get_working_days(organization: Organization, year: int = None, month: int = None) -> int:
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
