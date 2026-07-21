import nepali_datetime

from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.utils.html import strip_tags

from attendance.models import Attendance
from attendance.utils import get_attendance
from calendar_app.utilities import get_working_days, total_days_in_month
from task_management.models import Task
from task_management.utils import get_employee_task_summary

from .models import Employee, EmployeeAnalysisReport

TODAY = nepali_datetime.date.today()


def build_absolute_uri(request, relative_link):
    redirect_link = request.build_absolute_uri(relative_link)
    return redirect_link


def send_welcome_email(employee: Employee, redirect_link: str):
    from_email = 'noreply@meroadvice.com'
    recepient_list = [employee.user.email]

    html_message = render_to_string(
        'email_templates/welcome_email_template.html',
        {
            'receipent_name': employee.user.first_name,
            'organization': employee.organization,
            'subject': f'Welcome to {employee.organization.name}.',
            'redirect_link': redirect_link
        }
    )

    plain_message = strip_tags(html_message)
    email = EmailMultiAlternatives(
        f'Welcome to {employee.organization.name}.',
        plain_message,
        from_email,
        recepient_list
    )
    email.attach_alternative(html_message, 'text/html')
    email.send()


def get_analysis_report(employee: Employee, year: int = TODAY.year, month: int = TODAY.month) -> EmployeeAnalysisReport:
    tasks = get_employee_task_summary(
        employee=employee, year=year, month=month)

    pending_tasks = tasks.get('pending_tasks')
    on_going_tasks = tasks.get('on_going_tasks')
    completed_tasks = tasks.get('completed_tasks')

    total_tasks = pending_tasks + on_going_tasks + completed_tasks

    if total_tasks == 0:
        task_score = 100
    else:
        try:
            task_score = (completed_tasks/total_tasks) * 100
        except ZeroDivisionError:
            task_score = 0

    total_working_days = get_working_days(
        organization=employee.organization, year=year, month=month)

    present_days = Attendance.get_no_of_present_days(
        employee=employee, year=year, month=month)

    try:
        attendance_score = (present_days/total_working_days) * 100
    except ZeroDivisionError:
        attendance_score = 0

    reports = EmployeeAnalysisReport.objects.filter(employee=employee)

    report = None

    for item in reports:
        if item.date.year == year and item.date.month == month:
            report = item
            break

    if report is not None:
        report.task_score = task_score
        report.attendance_score = attendance_score
        report.date = TODAY
    else:
        report = EmployeeAnalysisReport.objects.create(
            organization=employee.organization, employee=employee, task_score=task_score, attendance_score=attendance_score)
        report.date = nepali_datetime.date(
            year=year, month=month, day=total_days_in_month(year=year, month=month))
    report.save()

    return report
