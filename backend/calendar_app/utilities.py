import nepali_datetime
import datetime

from calendar_app.models import Event
from organization.models import Organization

TODAY = nepali_datetime.date.today()


def count_saturdays(year: int, month: int) -> int:
    """
    Counts the number of Saturdays in a given month of a specified year
    using the Nepali calendar.

    Parameters:
        year (int): The year in the Nepali calendar.
        month (int): The month in the Nepali calendar (1 to 12).

    Returns:
        int: The total number of Saturdays in the specified month.

    """

    first_day = datetime.date(year, month, 1)

    if month == 12:
        next_month = datetime.date(year + 1, 1, 1)
    else:
        next_month = datetime.date(year, month + 1, 1)

    days_in_month = (next_month - first_day).days

    saturdays = sum(1 for day in range(1, days_in_month + 1)
                    if datetime.date(year, month, day).weekday() == 5)

    return saturdays


def count_holidays(organization: Organization, year: int, month: int) -> int:
    """
    Counts the total number of holiday days in a specific month for a given organization.

    This function filters events associated with the specified organization and counts 
    the days classified as holidays (`is_holiday=True`) for the given month and year.
    The holiday count is accumulated based on each event's duration.

    Parameters:
        organization (Organization): The organization to filter events for.
        year (int): The year to filter events by.
        month (int): The month to filter events by (1-12).

    Returns:
        int: The total number of holiday days in the specified month.
    """

    date_np = nepali_datetime.date(year=year, month=month, day=1)

    events = Event.objects.filter(
        organization=organization).order_by('start')

    holidays = 0

    for event in events:
        if event.start.year == date_np.year and event.start.month == date_np.month:
            if event.is_holiday:
                holidays += event.duration

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

    first_day = nepali_datetime.date(year, month, 1)

    if month == 12:
        next_month = nepali_datetime.date(year + 1, 1, 1)
    else:
        next_month = nepali_datetime.date(year, month + 1, 1)

    days_in_month = (next_month - first_day).days
    return days_in_month


def get_events(year: int = TODAY.year, month: int = TODAY.month):
    """
    Returns events in the given month of the year for the given organization.

    Parameters:
        organization: Organization
        year (int): The year of the month.
        month (int): The month (1-12).

    Returns:
        int: The total number of days in the specified month.
    """

    events = Event.objects.all()
    id_list = []
    for event in events:
        if event.start.year == year and event.start.month == month:
            id_list.append(event.id)

    return events.filter(id__in=id_list)


def get_working_days(organization: Organization, year: int = TODAY.year, month: str = TODAY.month) -> int:
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
    total_days = total_days_in_month(year=year, month=month)
    total_holidays = (count_saturdays(year=year, month=month) +
                      count_holidays(organization=organization, year=year, month=month))

    return total_days - total_holidays
