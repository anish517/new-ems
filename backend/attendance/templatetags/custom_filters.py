import nepali_datetime
from django import template

register = template.Library()


ENGLISH_DAYS = ['Sunday', 'Monday', 'Tuesday',
                'Wednesday', 'Thursday', 'Friday', 'Saturday']


@register.filter
def nepali_date_format(value):
    """
    Converts a Gregorian date to Nepali date and returns the formatted string
    with the day of the week in English.

    Example format: '2077-10-25 (Baisakh 12 Wednesday)'
    """
    if isinstance(value, (nepali_datetime.date, nepali_datetime.datetime)):
        # If the value is already a nepali_datetime date, we can directly format it
        nepali_date = value
    else:
        # Convert Gregorian date to Nepali date
        nepali_date = nepali_datetime.date(value.year, value.month, value.day)

    # Get the day of the week in Nepali (0=Sunday, 6=Saturday)
    nepali_day_of_week = nepali_date.weekday()

    # Get the day name in English from the list
    english_day_name = ENGLISH_DAYS[nepali_day_of_week]

    # Format the Nepali date (without day in Nepali) and add the English day name
    formatted_date = nepali_date.strftime(
        '%Y-%m-%d') + f', {english_day_name}'

    return formatted_date
