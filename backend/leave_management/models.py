from django.db import models
from django.contrib.auth import get_user_model
from nepali_datetime_field.models import NepaliDateField
from django_ckeditor_5.fields import CKEditor5Field
from tinymce.models import HTMLField
import nepali_datetime

from organization.models import Employee, Organization
from utils.models import SoftDeleteModel

User = get_user_model()


class LeaveSetting(models.Model):
    organization = models.OneToOneField(
        Organization, on_delete=models.CASCADE, related_name='leave_setting', null=True, blank=True
    )
    paid_leave_during_provision = models.BooleanField(
        default=False, verbose_name="Paid Leave During Provision Period"
    )
    allow_intern_leave = models.BooleanField(
        default=True, verbose_name="Allow Intern Leave"
    )

    def __str__(self):
        return f"LeaveSetting for {self.organization.name if self.organization else 'Global'}"


class LeaveType(models.Model):
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, null=True, blank=True)
    name = models.CharField(null=True, max_length=255)
    quota = models.IntegerField(null=True, default=0)
    is_sick_leave = models.BooleanField(default=False)
    is_casual_leave = models.BooleanField(default=False)

    def __str__(self):
        return f'{self.name}'


class LeaveBalance(models.Model):
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, null=True)
    employee = models.ForeignKey(Employee, on_delete=models.CASCADE, null=True)
    leave_type = models.ForeignKey(
        LeaveType, on_delete=models.CASCADE, null=True)
    quota = models.IntegerField(default=0)
    leaves_taken = models.FloatField(default=0, null=True)

    def __str__(self) -> str:
        return self.employee.user.full_name if self.employee and getattr(self.employee, 'user', None) else 'LeaveBalance'


class LeaveRequest(SoftDeleteModel):
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, null=True)
    employee = models.ForeignKey(
        Employee, on_delete=models.CASCADE, null=True, blank=True)
    type = models.ForeignKey(
        LeaveType, on_delete=models.CASCADE, null=True, blank=True)
    from_date = NepaliDateField()
    till_date = NepaliDateField()
    subject = models.CharField(max_length=500)
    reason_for_leave = CKEditor5Field(
        null=True, blank=True, config_name='extends')
    is_approved = models.BooleanField(default=False)
    is_reviewed = models.BooleanField(default=False)
    is_paid = models.BooleanField(default=False)
    remarks = models.TextField(max_length=5000, blank=True, default='')
    created_at = NepaliDateField(null=True, blank=True)
    
    # 2-Tier Approval Fields for Sick Leave
    is_initial_approved = models.BooleanField(default=False)
    initial_approved_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True, related_name='initial_approved_leaves')
    initial_approved_at = models.DateTimeField(null=True, blank=True)

    # Mandatory Rejection Reason
    rejection_reason = models.TextField(max_length=1000, null=True, blank=True)

    # Supporting Medical Document for Sick Leave
    document = models.FileField(upload_to='leave_documents/', null=True, blank=True)
    
    is_half_day = models.BooleanField(default=False)
    HALF_DAY_CHOICES = (
        ('First Half', 'First Half'),
        ('Second Half', 'Second Half'),
    )
    half_day_period = models.CharField(max_length=20, choices=HALF_DAY_CHOICES, null=True, blank=True)

    def __str__(self):
        return f'{self.subject}-{self.is_approved}'

    def save(self, *args, **kwargs):
        if not self.created_at:
            self.created_at = nepali_datetime.date.today()
        if self.is_half_day and self.from_date:
            self.till_date = self.from_date
        super().save(*args, **kwargs)

    @property
    def owner(self):
        return self.employee

    def _get_org_holiday_keys(self) -> set:
        org = self.organization or (getattr(self.employee, 'organization', None) if self.employee else None)
        if not org or not self.from_date:
            return set()
        till = self.till_date if self.till_date and self.till_date >= self.from_date else self.from_date
        try:
            from calendar_app.utilities import get_holiday_dates
            holiday_keys = set()
            curr_y, curr_m = self.from_date.year, self.from_date.month
            end_y, end_m = till.year, till.month
            while (curr_y, curr_m) <= (end_y, end_m):
                holiday_keys |= get_holiday_dates(org, curr_y, curr_m)
                if curr_m == 12:
                    curr_y += 1
                    curr_m = 1
                else:
                    curr_m += 1
            return holiday_keys
        except Exception:
            return set()

    @property
    def no_days(self):
        if not self.from_date:
            return 0.0
        holiday_keys = self._get_org_holiday_keys()
        if self.is_half_day:
            try:
                if self.from_date.weekday() == 6:
                    return 0.0
            except Exception:
                pass
            if (self.from_date.year, self.from_date.month, self.from_date.day) in holiday_keys:
                return 0.0
            return 0.5
        if not self.till_date:
            return 0.0
        import datetime as py_dt
        days = 0.0
        curr = self.from_date
        while curr <= self.till_date:
            is_sat = False
            try:
                is_sat = (curr.weekday() == 6)
            except Exception:
                try:
                    is_sat = (curr.to_datetime_date().isoweekday() == 6)
                except Exception:
                    is_sat = False
            is_hol = (curr.year, curr.month, curr.day) in holiday_keys
            if not is_sat and not is_hol:
                days += 1.0
            try:
                curr = curr + py_dt.timedelta(days=1)
            except Exception:
                break
        return days


    @property
    def files(self):
        return self.leave_requests.all()

    def days_in_month_range(self, year: int, month: int, start_day: int = 1, end_day: int | None = None, exclude_dates: set | None = None) -> float:
        """
        Returns how many working leave days of this LeaveRequest fall within
        the given (year, month) and [start_day..end_day], excluding Saturdays
        and any dates in `exclude_dates` (such as public holidays).
        """
        if not self.from_date:
            return 0.0
        from calendar_app.utilities import total_days_in_month
        import datetime as py_dt

        year_i, month_i = year, month
        m_days = total_days_in_month(year_i, month_i)
        s_day = max(1, min(start_day, m_days))
        e_day = m_days if end_day is None else max(1, min(end_day, m_days))
        if s_day > e_day:
            return 0.0

        range_start = nepali_datetime.date(year_i, month_i, s_day)
        range_end = nepali_datetime.date(year_i, month_i, e_day)
        till = self.till_date if self.till_date and self.till_date >= self.from_date else self.from_date

        if till < range_start or self.from_date > range_end:
            return 0.0

        if self.is_half_day:
            if range_start <= self.from_date <= range_end:
                if self.from_date.weekday() == 6:
                    return 0.0
                key = (self.from_date.year, self.from_date.month, self.from_date.day)
                if exclude_dates and key in exclude_dates:
                    return 0.0
                return 0.5
            return 0.0

        curr = max(self.from_date, range_start)
        clip_end = min(till, range_end)
        days = 0.0
        while curr <= clip_end:
            is_saturday = (curr.weekday() == 6)
            key = (curr.year, curr.month, curr.day)
            is_excluded = bool(exclude_dates and key in exclude_dates)
            if not is_saturday and not is_excluded:
                days += 1.0
            try:
                curr = curr + py_dt.timedelta(days=1)
            except Exception:
                break
        return days

    @staticmethod
    def get_total_paid_leaves(employee: Employee, year: int, month: int, start_day: int = 1, exclude_dates: set | None = None):
        leave_requests = LeaveRequest.objects.filter(
            employee=employee, is_paid=True, is_approved=True
        )
        if exclude_dates is None:
            from calendar_app.utilities import get_holiday_dates
            org = getattr(employee, 'organization', None)
            exclude_dates = get_holiday_dates(org, year, month, start_day=start_day) if org else set()

        total_days = 0.0
        for leave_request in leave_requests:
            total_days += leave_request.days_in_month_range(
                year=year,
                month=month,
                start_day=start_day,
                exclude_dates=exclude_dates,
            )

        return total_days

    @staticmethod
    def get_total_unpaid_leaves(employee: Employee, year: int, month: int, start_day: int = 1, exclude_dates: set | None = None):
        leave_requests = LeaveRequest.objects.filter(
            employee=employee, is_paid=False, is_approved=True
        )
        if exclude_dates is None:
            from calendar_app.utilities import get_holiday_dates
            org = getattr(employee, 'organization', None)
            exclude_dates = get_holiday_dates(org, year, month, start_day=start_day) if org else set()

        total_days = 0.0
        for leave_request in leave_requests:
            total_days += leave_request.days_in_month_range(
                year=year,
                month=month,
                start_day=start_day,
                exclude_dates=exclude_dates,
            )

        return total_days

    @staticmethod
    def get_total_half_leaves(employee: Employee, year: int, month: int):
        leave_requests = LeaveRequest.objects.filter(employee=employee, is_half_day=True, is_approved=True)
        total_half_days = 0
        for leave_request in leave_requests:
            if leave_request.from_date and leave_request.from_date.year == year and leave_request.from_date.month == month:
                total_half_days += 1
        return total_half_days


class LeaveRequestFiles(models.Model):
    leave_request = models.ForeignKey(
        LeaveRequest, on_delete=models.CASCADE, blank=True, null=True, related_name='files')
    file = models.FileField(upload_to='leave_requests/', null=True, blank=True)

