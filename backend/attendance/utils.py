import nepali_datetime
from math import radians, sin, cos, sqrt, atan2
from datetime import timedelta
from django.db.models.query import QuerySet


from calendar_app.utilities import total_days_in_month
from .models import Attendance, CheckInOut
from organization.models import Employee, Organization

TODAY = nepali_datetime.date.today()


def get_checked_employees(organization: Organization, year: int = TODAY.year, month: int = TODAY.month, day: int = TODAY.day) -> QuerySet[Attendance]:
    """
    Returns queryset of Attendances that has checked in time.
    """
    date = nepali_datetime.date(year=year, month=month, day=day)
    attendances = Attendance.objects.filter(
        organization=organization, date=date)
    attendance_ids = [
        attendance.id for attendance in attendances if attendance.has_checked_in()]
    return Attendance.objects.filter(id__in=attendance_ids)


def get_absent_employees(organization: Organization, year: int = TODAY.year, month: int = TODAY.today().month, day: int = TODAY.today().day) -> QuerySet[Attendance]:
    """
    Returns queryset of Attendances that has checked in time.
    """
    date = nepali_datetime.date(year=year, month=month, day=day)
    employees = organization.employees
    absent_employee_ids = []
    for employee in employees:
        attendance = Attendance.objects.filter(
            employee=employee, date=date)
        if not attendance.exists() or not attendance.first().has_checked_in():
            absent_employee_ids.append(employee.pk)

    return Employee.objects.filter(id__in=absent_employee_ids)


def get_employees_attendance_list(organization: Organization,):
    employees = organization.employees
    attendance_list = []
    for employee in employees:
        item = {}
        item['employee'] = {
            'id': employee.pk,
            'name': employee.user.full_name,
            'post': employee.post.title,
            'email': employee.official_email,
            'profile_picture': employee.user.get_profile_picture,
        }
        item['working_hour'], item['shift_covered'] = get_working_hour(
            employee=employee)
        if Attendance.check_in_time(employee=employee):
            item['check_in_time'] = Attendance.check_in_time(
                employee=employee).check_in
        else:
            item['check_in_time'] = None

        item['has_checked_in_today'] = Attendance.has_checked_in_today(
            employee=employee)

        attendance_list.append(item)
    return attendance_list


def get_attendance(employee: Employee, year: int = TODAY.year, month: int = TODAY.month):
    last_day = total_days_in_month(year=year, month=month)
    start_date = nepali_datetime.date(year=year, month=month, day=1)
    max_date = nepali_datetime.date(year=year, month=month, day=last_day)
    attendance_ids = []
    while start_date <= max_date:
        attendance, created = Attendance.objects.get_or_create(
            employee=employee, date=start_date, defaults={
                'organization': employee.organization
            })
        start_date = start_date + timedelta(1)
        attendance_ids.append(attendance.pk)
    attendance_qs = Attendance.objects.filter(
        id__in=attendance_ids).order_by('date')
    return attendance_qs


def get_working_hour(employee: Employee, year: int = TODAY.year, month: int = TODAY.month, day: int = TODAY.day):
    date = nepali_datetime.date(year=year, month=month, day=day)
    organization: Organization = employee.organization

    if organization.opening_time and organization.closing_time:
        shift_start = nepali_datetime.datetime.combine(
            nepali_datetime.datetime.now().date(), organization.opening_time)
        shift_end = nepali_datetime.datetime.combine(
            nepali_datetime.datetime.now().date(), organization.closing_time)
        total_shift_duration = (shift_end - shift_start).total_seconds()
    else:
        return "0 Hrs 0 Mins", 0

    try:
        attendance = Attendance.objects.get(employee=employee, date=date)
    except Attendance.DoesNotExist:
        return "0 Hrs 0 Mins", 0

    working_hour = attendance.working_hour().total_seconds()
    percentage = (working_hour / total_shift_duration) * 100

    return attendance.formated_working_hour(), round(percentage)


def average_working_hour(employee: Employee, year: int = TODAY.year, month: int = TODAY.year):
    date = nepali_datetime.date(year=year, month=month, day=1)
    attendances = get_attendance(
        employee=employee, year=date.year, month=date.month)

    total_working_hour = 0
    no_of_days = 0
    for attendance in attendances:
        if attendance.has_checked_in():
            total_working_hour += attendance.working_hour().seconds
            no_of_days += 1

    try:
        average_working_hour = total_working_hour / no_of_days
    except ZeroDivisionError:
        return f"0 Hrs 0 Mins"
    hours, remainder = divmod(average_working_hour, 3600)
    minutes, seconds = divmod(remainder, 60)
    return f"{round(hours)} Hrs {round(minutes)} Mins"


def is_within_radius(current_lat: float, current_lng: float, target_lat: float, target_lng: float) -> bool:
    """
    Check if the current location is within a specified radius of the target location.

    Args:
        current_lat (float): Current latitude of the user.
        current_lng (float): Current longitude of the user.
        target_lat (float): Latitude of the target location.
        target_lng (float): Longitude of the target location.

    Returns:
        bool: True if the current location is within the radius, False otherwise.
    """

    EARTH_RADIUS = 6371000  # Earth's radius in meters
    RADIUS_METERS = 50  # 50m radius — matches the text shown in the app UI
    delta_lat = radians((target_lat) - current_lat)
    delta_lon = radians(target_lng - current_lng)

    a = sin(delta_lat / 2) ** 2 + cos(radians(current_lat)) * \
        cos(radians(target_lat)) * sin(delta_lon / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))

    distance = EARTH_RADIUS * c
    return distance <= RADIUS_METERS
