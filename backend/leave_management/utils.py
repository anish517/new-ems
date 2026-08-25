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


def ensure_default_leave_types_and_settings(organization):
    """
    Ensures Casual Leave (12 days) and Sick Leave (8 days) exist for the organization,
    and ensures LeaveSetting exists.
    """
    from .models import LeaveType, LeaveSetting, LeaveBalance
    if not organization:
        return
    
    LeaveSetting.objects.get_or_create(
        organization=organization,
        defaults={
            'paid_leave_during_provision': False,
            'allow_intern_leave': True,
        }
    )
    
    # Casual Leave (12 days annually)
    casual_type = LeaveType.objects.filter(
        organization=organization,
        is_casual_leave=True
    ).first()
    if not casual_type:
        casual_type = LeaveType.objects.filter(
            organization=organization,
            name__iexact='Casual Leave'
        ).first()
    if not casual_type:
        casual_type = LeaveType.objects.create(
            organization=organization,
            name='Casual Leave',
            quota=12,
            is_casual_leave=True,
            is_sick_leave=False,
        )
    elif casual_type.quota != 12 or not casual_type.is_casual_leave:
        casual_type.quota = 12
        casual_type.is_casual_leave = True
        casual_type.save(update_fields=['quota', 'is_casual_leave'])

    # Sick Leave (8 days annually)
    sick_type = LeaveType.objects.filter(
        organization=organization,
        is_sick_leave=True
    ).first()
    if not sick_type:
        sick_type = LeaveType.objects.filter(
            organization=organization,
            name__iexact='Sick Leave'
        ).first()
    if not sick_type:
        sick_type = LeaveType.objects.create(
            organization=organization,
            name='Sick Leave',
            quota=8,
            is_sick_leave=True,
            is_casual_leave=False,
        )
    elif sick_type.quota != 8 or not sick_type.is_sick_leave:
        sick_type.quota = 8
        sick_type.is_sick_leave = True
        sick_type.save(update_fields=['quota', 'is_sick_leave'])

    # Clean up legacy LeaveTypes (such as old 'Paid Leave' and 'Unpaid Leave' rows)
    legacy_types = LeaveType.objects.filter(
        organization=organization
    ).exclude(
        id__in=[casual_type.id, sick_type.id]
    )
    for lt in legacy_types:
        LeaveRequest.objects.filter(type=lt).update(type=casual_type)
        LeaveBalance.objects.filter(leave_type=lt).delete()
    legacy_types.delete()

    # Ensure LeaveBalances exist for all employees in org
    for emp in organization.employees:
        LeaveBalance.objects.get_or_create(
            organization=organization,
            employee=emp,
            leave_type=casual_type,
            defaults={'quota': 12, 'leaves_taken': 0.0}
        )
        LeaveBalance.objects.get_or_create(
            organization=organization,
            employee=emp,
            leave_type=sick_type,
            defaults={'quota': 8, 'leaves_taken': 0.0}
        )


def get_employee_leave_breakdown(employee: Employee, year: int = None, month: int = None):
    """
    Calculates detailed leave breakdown for Casual & Sick leaves with monthly accumulation,
    carry-forward, and multi-metric staff quota tracking.
    """
    from .models import LeaveType, LeaveBalance
    if not year or not month:
        today = nepali_datetime.date.today()
        year = year or today.year
        month = month or today.month

    organization = employee.organization
    if organization:
        ensure_default_leave_types_and_settings(organization)

    def _get_year(d):
        if not d:
            return None
        if hasattr(d, 'year'):
            return d.year
        try:
            return int(str(d).split('-')[0])
        except Exception:
            return None

    # Determine employee joining date in Nepali calendar (BS)
    joined_year = None
    joined_month = None
    joined_day = None

    if getattr(employee, 'date_of_joining', None):
        doj = employee.date_of_joining
        try:
            if hasattr(doj, 'year'):
                joined_year = doj.year
                joined_month = doj.month
                joined_day = doj.day
            else:
                parts = str(doj).split('-')
                joined_year = int(parts[0])
                joined_month = int(parts[1])
                joined_day = int(parts[2]) if len(parts) > 2 else 1
        except Exception:
            pass

    if not joined_year:
        date_joined_dt = None
        if hasattr(employee, 'user') and employee.user and getattr(employee.user, 'date_joined', None):
            date_joined_dt = employee.user.date_joined
        elif hasattr(employee, 'created_at') and getattr(employee, 'created_at', None):
            date_joined_dt = employee.created_at

        if date_joined_dt:
            try:
                if hasattr(date_joined_dt, 'date'):
                    greg_date = date_joined_dt.date()
                else:
                    greg_date = date_joined_dt
                bs_date = nepali_datetime.date.from_datetime_date(greg_date)
                joined_year = bs_date.year
                joined_month = bs_date.month
                joined_day = bs_date.day
            except Exception:
                pass

    # Get all approved leave requests for this employee in this year
    all_approved = LeaveRequest.objects.filter(
        employee=employee,
        is_approved=True,
        is_reviewed=True,
    )
    year_approved = [lr for lr in all_approved if _get_year(lr.from_date) == year]

    leave_types = LeaveType.objects.filter(
        organization=organization,
        name__in=['Casual Leave', 'Sick Leave']
    ).order_by('id') if organization else LeaveType.objects.filter(
        name__in=['Casual Leave', 'Sick Leave']
    ).order_by('id')

    # If no leave types yet, fallback
    if not leave_types.exists() and organization:
        ensure_default_leave_types_and_settings(organization)
        leave_types = LeaveType.objects.filter(organization=organization, name__in=['Casual Leave', 'Sick Leave']).order_by('id')

    from calendar_app.utilities import total_days_in_month

    breakdown = []
    for lt in leave_types:
        is_casual = lt.is_casual_leave or (lt.name and 'casual' in lt.name.lower())
        is_sick = lt.is_sick_leave or (lt.name and 'sick' in lt.name.lower())

        full_annual_quota = float(lt.quota or (12 if is_casual else (8 if is_sick else 0)))
        monthly_rate = full_annual_quota / 12.0

        # --- Tenure-based Pro-rata Calculation ---
        if joined_year and joined_month and joined_year == year:
            # Employee joined during this fiscal year
            dim = total_days_in_month(joined_year, joined_month)
            if not dim or dim <= 0:
                dim = 30
            
            # Exact fractional month worked in the joining month
            joining_month_fraction = max(0.0, min(1.0, (dim - (joined_day or 1) + 1) / float(dim)))
            
            # Prorated Annual Quota for remaining fiscal year (from joined_month to 12)
            remaining_months = max(0.0, (12 - joined_month) + joining_month_fraction)
            annual_quota = round(monthly_rate * remaining_months, 2)
            
            # Accrued to requested month:
            if month < joined_month:
                accrued_to_date = 0.0
            elif month == joined_month:
                accrued_to_date = round(monthly_rate * joining_month_fraction, 2)
            else:
                completed_months_after_joining = (month - joined_month)
                active_tenure_months = completed_months_after_joining + joining_month_fraction
                accrued_to_date = min(annual_quota, round(monthly_rate * active_tenure_months, 2))
        elif joined_year and joined_year > year:
            # Employee joined in a future year -> 0 quota for this year
            annual_quota = 0.0
            accrued_to_date = 0.0
        else:
            # Employee joined in prior year -> standard full annual quota and month accrual
            annual_quota = full_annual_quota
            accrued_to_date = min(annual_quota, round(monthly_rate * month, 2))

        # Filter requests for this leave type
        type_reqs = [
            lr for lr in year_approved
            if lr.type_id == lt.id or (lr.type is None and ((is_casual and lr.is_paid) or (is_sick and lr.is_paid)))
        ]

        paid_taken = float(sum(lr.no_days for lr in type_reqs if lr.is_paid))
        unpaid_taken = float(sum(lr.no_days for lr in type_reqs if not lr.is_paid))
        half_day_reqs = [lr for lr in type_reqs if lr.is_half_day]
        half_day_count = len(half_day_reqs)
        half_day_days = float(sum(lr.no_days for lr in half_day_reqs))

        available_this_month = max(0.0, round(accrued_to_date - paid_taken, 2))
        remaining_annual = max(0.0, round(annual_quota - paid_taken, 2))

        # Get or update LeaveBalance
        lb, _ = LeaveBalance.objects.get_or_create(
            employee=employee,
            leave_type=lt,
            defaults={'organization': organization, 'quota': int(annual_quota), 'leaves_taken': paid_taken}
        )
        if lb.leaves_taken != paid_taken or lb.quota != int(annual_quota):
            lb.leaves_taken = paid_taken
            lb.quota = int(annual_quota)
            lb.save(update_fields=['leaves_taken', 'quota'])

        breakdown.append({
            'id': lb.id,
            'leave_type': {
                'id': lt.id,
                'name': lt.name,
                'quota': int(annual_quota),
                'is_sick_leave': lt.is_sick_leave,
                'is_casual_leave': lt.is_casual_leave,
            },
            'is_casual_leave': is_casual,
            'is_sick_leave': is_sick,
            'annual_quota': annual_quota,
            'quota': int(annual_quota),
            'accrued_to_date': accrued_to_date,
            'available_this_month': available_this_month,
            'leaves_taken': paid_taken,
            'paid_taken': paid_taken,
            'unpaid_taken': unpaid_taken,
            'half_day_count': half_day_count,
            'half_day_days': half_day_days,
            'remaining_annual': remaining_annual,
            'is_prorated': (joined_year == year),
        })

    return breakdown


def get_employee_leave_request(employee: Employee, year: int = TODAY.year, month: int = TODAY.month) -> int:
    no_of_days = 0

    leave_requests = LeaveRequest.objects.filter(
        employee=employee, is_approved=True)
    leave_request_ids = []
    for request in leave_requests:
        if request.created_at.year == year and request.created_at.month == month:
            leave_request_ids.append(request.id)
    return LeaveRequest.objects.filter(id__in=leave_request_ids)

