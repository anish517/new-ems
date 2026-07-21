import nepali_datetime
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from collections import defaultdict
from django.db.models.query import QuerySet

from organization.models import Employee, Organization
from .models import LeaveRequest, LeaveBalance


TODAY = nepali_datetime.date.today()


def send_leave_email(employee: Employee, leave_request: LeaveRequest):
    from_email = 'noreply@meroadvice.com'
    recepient_list = [employee.user.email]

    html_message = render_to_string(
        'email_templates/leave_request_email_template.html',
        {
            'company_name': employee.organization,
            'receipent_name': employee.user.first_name,
            'subject': 'Your leave request has been submitted',
            'leave_request': leave_request,
        }
    )

    plain_message = strip_tags(html_message)
    email = EmailMultiAlternatives(
        'Your leave request has been submitted',
        plain_message,
        from_email,
        recepient_list
    )
    email.attach_alternative(html_message, 'text/html')
    email.send()


def send_leave_approval_email(employee: Employee, leave_request: LeaveRequest, redirect_link: str):
    from_email = 'noreply@meroadvice.com'
    recepient_list = [employee.user.email]

    html_message = render_to_string(
        'email_templates/leave_request_email_template.html',
        {
            'company_name': employee.organization,
            'receipent_name': employee.user.first_name,
            'subject': 'Your leave request has been approved',
            'leave_request': leave_request,
            'redirect_link': redirect_link
        }
    )

    plain_message = strip_tags(html_message)
    email = EmailMultiAlternatives(
        'Your leave request has been submitted',
        plain_message,
        from_email,
        recepient_list
    )
    email.attach_alternative(html_message, 'text/html')
    email.send()


def send_leave_declined_email(employee: Employee, leave_request: LeaveRequest, redirect_link: str):
    from_email = 'noreply@meroadvice.com'
    recepient_list = [employee.user.email]

    html_message = render_to_string(
        'email_templates/leave_request_email_template.html',
        {
            'company_name': employee.organization,
            'receipent_name': employee.user.first_name,
            'subject': 'Your leave request has been declined',
            'leave_request': leave_request,
            'redirect_link': redirect_link
        }
    )

    plain_message = strip_tags(html_message)
    email = EmailMultiAlternatives(
        'Your leave request has been submitted',
        plain_message,
        from_email,
        recepient_list
    )
    email.attach_alternative(html_message, 'text/html')
    email.send()


def get_years_till_current(start_year: int) -> list:
    current_year = nepali_datetime.datetime.today().year
    return list(range(start_year, current_year + 1))


def get_leave_balance_by_employee(organization):
    # Filter LeaveBalance entries by organization ID
    leave_balances = LeaveBalance.objects.filter(
        organization=organization)

    # Group results by employee
    leave_balance_by_employee = defaultdict(list)
    for leave_balance in leave_balances:
        leave_balance_by_employee[leave_balance.employee].append(leave_balance)

    # Transform to a list of dictionaries with sorted leave balances
    result = [
        {
            "employee": employee,
            "leave_balances": sorted(leave_balances, key=lambda lb: lb.leave_type.name)[0:2]
        }
        for employee, leave_balances in leave_balance_by_employee.items()
    ]

    return result


def get_employees_on_leave(organization: Organization, year: int = None, month: int = None, day: int = None) -> QuerySet[LeaveRequest]:
    if year and month and day:
        date = nepali_datetime.date(year=year, month=month, day=day)
    else:
        date = nepali_datetime.date.today()
    leave_requests = LeaveRequest.objects.filter(organization=organization)
    filtered_leave_requests = [
        leave_request.id for leave_request in leave_requests if leave_request.from_date <= date and leave_request.till_date >= date]

    filtered_qs = leave_requests.filter(id__in=filtered_leave_requests)
    return filtered_qs


def get_employee_leave_days(employee: Employee, year: int = TODAY.year, month: int = TODAY.month) -> int:

    no_of_days = 0

    leave_requests = LeaveRequest.objects.filter(
        employee=employee, is_approved=True)

    for request in leave_requests:
        if request.created_at.year == year and request.created_at.month == month:
            no_of_days += request.no_days

    return no_of_days


def get_employee_leave_request(employee: Employee, year: int = TODAY.year, month: int = TODAY.month) -> int:
    no_of_days = 0

    leave_requests = LeaveRequest.objects.filter(
        employee=employee, is_approved=True)
    leave_request_ids = []
    for request in leave_requests:
        if request.created_at.year == year and request.created_at.month == month:
            leave_request_ids.append(request.id)
    return LeaveRequest.objects.filter(id__in=leave_request_ids)
