import nepali_datetime
from django.db import models
from nepali_datetime_field.models import NepaliDateField
from django_ckeditor_5.fields import CKEditor5Field

from attendance.models import Attendance
from fiscal_year.models import FiscalYear
from organization.models import Employee, Organization
from leave_management.models import LeaveRequest
from calendar_app.utilities import count_saturdays, count_holidays, get_holiday_dates, total_days_in_month
from utils.models import SoftDeleteModel

# Create your models here.


class NepaliMonthChoices(models.TextChoices):
    BAISHAKH = 'BAI', 'Baishakh'
    JESTHA = 'JES', 'Jestha'
    ASHADH = 'ASH', 'Ashadh'
    SHRAWAN = 'SHR', 'Shrawan'
    BHADRA = 'BHA', 'Bhadra'
    ASHWIN = 'ASW', 'Ashwin'
    KARTIK = 'KAR', 'Kartik'
    MANGSIR = 'MAN', 'Mangsir'
    POUSH = 'POU', 'Poush'
    MAGH = 'MAG', 'Magh'
    FALGUN = 'FAL', 'Falgun'
    CHAITRA = 'CHA', 'Chaitra'


class Salary(SoftDeleteModel):
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, null=True)
    employee = models.OneToOneField(
        Employee, on_delete=models.CASCADE, related_name='salary', null=True)
    basic_salary = models.FloatField(default=0, null=True)
    remote_salary = models.FloatField(default=0, null=True)
    ssf = models.FloatField(default=0, null=True,
                            verbose_name='Social security fund (SSF)')
    tds = models.FloatField(default=0, null=True,
                            verbose_name='Tax deducted at source (TDS)')
    epf = models.FloatField(default=0, null=True,
                            verbose_name='Employee provident fund (EPF)')
    citizen_investment_trust = models.FloatField(default=0, null=True)
    insurance = models.FloatField(default=0, null=True)
    tax_rate = models.FloatField(default=0, null=True, blank=True,
                                 verbose_name='Tax Rate (%)')

    def __str__(self) -> str:
        return f'{self.employee.user.full_name}'

    @staticmethod
    def get_employee_joining_bs(employee: Employee):
        if getattr(employee, 'date_of_joining', None):
            doj = employee.date_of_joining
            try:
                if hasattr(doj, 'year'):
                    return doj.year, doj.month, doj.day
                parts = str(doj).split('-')
                return int(parts[0]), int(parts[1]), int(parts[2]) if len(parts) > 2 else 1
            except Exception:
                pass

        date_joined_dt = None
        if hasattr(employee, 'user') and employee.user and getattr(employee.user, 'date_joined', None):
            date_joined_dt = employee.user.date_joined
        elif hasattr(employee, 'created_at') and getattr(employee, 'created_at', None):
            date_joined_dt = employee.created_at

        if date_joined_dt:
            try:
                greg_date = date_joined_dt.date() if hasattr(date_joined_dt, 'date') else date_joined_dt
                bs_date = nepali_datetime.date.from_datetime_date(greg_date)
                return bs_date.year, bs_date.month, bs_date.day
            except Exception:
                pass
        return None, None, None

    @staticmethod
    def calculate_gross_salary(employee: Employee, year: int, month: int, holidays_override=None):
        organization = employee.organization
        days_in_month = total_days_in_month(year, month)

        # Check employee joining date
        joined_year, joined_month, joined_day = Salary.get_employee_joining_bs(employee)

        # 1. If employee has not joined yet in this month/year -> 0 salary
        if joined_year:
            if year < joined_year or (year == joined_year and month < joined_month):
                return 0.0

        # Determine active start day for this month
        start_day = 1
        if joined_year and year == joined_year and month == joined_month:
            start_day = max(1, min(joined_day, days_in_month))

        attendances = Attendance.get_attendance_of_selected_month(
            employee=employee, year=year, month=month)

        raw_present = [
            attendance for attendance in attendances if attendance.has_checked_in()]

        # Deduplicate real nepali_datetime.date attendance records by calendar date
        # (and ignore records prior to start_day for mid-month joiners), while preserving
        # mock attendance objects used in unit tests.
        # Note: nepali_datetime.date.__hash__ is broken on Python 3.13, so we key by (year, month, day) tuples.
        dedup_by_date = {}
        present_date_objs = {}
        mock_present = []
        for att in raw_present:
            att_date = getattr(att, 'date', None)
            if isinstance(att_date, nepali_datetime.date):
                if att_date.day < start_day:
                    continue
                att_key = (att_date.year, att_date.month, att_date.day)
                present_date_objs[att_key] = att_date
                if att_key not in dedup_by_date:
                    dedup_by_date[att_key] = att
                else:
                    # If any check-in on that date was on-site, treat the day as on-site
                    if not getattr(att, 'is_remote', False):
                        dedup_by_date[att_key] = att
            else:
                mock_present.append(att)

        days_present = list(dedup_by_date.values()) + mock_present
        present_keys = set(dedup_by_date.keys())

        remote_attendance = float(len([
            attendance for attendance in days_present if attendance.is_remote]))
        site_attendance = float(len([
            attendance for attendance in days_present if not attendance.is_remote]))

        paid_leaves = LeaveRequest.get_total_paid_leaves(
            employee=employee, year=year, month=month)

        actual_cal_days = nepali_datetime._days_in_month(year, month)
        safe_end_day = min(days_in_month, actual_cal_days)
        saturday_keys = {
            (year, month, d)
            for d in range(start_day, safe_end_day + 1)
            if nepali_datetime.date(year, month, d).weekday() == 6
        }
        holiday_keys = get_holiday_dates(organization, year=year, month=month, start_day=start_day, end_day=safe_end_day)
        off_keys = saturday_keys | holiday_keys

        if holidays_override is not None:
            holidays = holidays_override
        else:
            # Exclude off-days where the employee also checked in so a Saturday/holiday
            # check-in is never double-counted as 2.0 paid days for 1 calendar date.
            holidays = len(off_keys - present_keys)

        # 30-Day Basis Calculation
        salary_qs = Salary.objects.filter(employee=employee)
        if not salary_qs.exists():
            return 0.0
        salary_obj = salary_qs.first()

        per_day_rate = (salary_obj.basic_salary or 0.0) / 30.0
        # If remote_salary is 0 or unset, default remote days to the standard basic_salary rate
        effective_remote_salary = (
            salary_obj.remote_salary
            if (salary_obj.remote_salary is not None and salary_obj.remote_salary > 0)
            else (salary_obj.basic_salary or 0.0)
        )
        remote_per_day = effective_remote_salary / 30.0

        # Prevent double-counting full-day paid leaves on dates where the employee also checked in
        full_paid_leave_overlap = 0.0
        if present_keys:
            full_paid_leaves = LeaveRequest.objects.filter(
                employee=employee, is_half_day=False, is_paid=True, is_approved=True
            )
            overlap_keys = set()
            for lr in full_paid_leaves:
                if not lr.from_date:
                    continue
                till = lr.till_date if lr.till_date and lr.till_date >= lr.from_date else lr.from_date
                for p_key, p_date in present_date_objs.items():
                    if p_key not in off_keys and lr.from_date <= p_date <= till:
                        overlap_keys.add(p_key)
            full_paid_leave_overlap = float(len(overlap_keys))

        # Total paid days (they get credit for attendance, paid leaves, and holidays during active employment)
        paid_days = site_attendance + remote_attendance + max(0.0, paid_leaves - full_paid_leave_overlap) + holidays

        # Half-Day Leave + Check-In Deduplication (both Paid and Unpaid half-day leaves):
        # When an employee takes an approved half-day leave and checks in for the other half:
        # - site_attendance/remote_attendance gave them 1.0 full day for checking in.
        # - If the half-day leave is PAID, paid_leaves also added +0.5 (total 1.5 without adjustment).
        # - If the half-day leave is UNPAID, paid_leaves added 0.0 (total 1.0 without adjustment).
        # Subtracting 0.5 for each checked-in half-day leave yields 1.0 paid day for paid half-leave
        # and 0.5 paid day for unpaid half-leave.
        approved_half_leaves = LeaveRequest.objects.filter(
            employee=employee, is_half_day=True, is_approved=True
        )
        half_leave_keys = {
            (lr.from_date.year, lr.from_date.month, lr.from_date.day)
            for lr in approved_half_leaves
            if lr.from_date and lr.from_date.year == year and lr.from_date.month == month
            and (lr.from_date.year, lr.from_date.month, lr.from_date.day) not in off_keys
        }
        for attendance in days_present:
            att_date = getattr(attendance, 'date', None)
            if isinstance(att_date, nepali_datetime.date):
                att_key = (att_date.year, att_date.month, att_date.day)
                if att_key in half_leave_keys:
                    paid_days -= 0.5
                    if getattr(attendance, 'is_remote', False):
                        remote_attendance = max(0.0, remote_attendance - 0.5)

        if paid_days <= 0:
            return 0.0

        # Calculate unpaid absences by comparing actual days in month to their paid days
        # (For mid-month joinees, unworked days prior to joining date are automatically in (days_in_month - paid_days))
        unpaid_absences = max(0.0, days_in_month - paid_days)

        # Start with the full 30-day base salary, and deduct any unpaid absences
        base_salary = salary_obj.basic_salary or 0.0
        base_payout = max(0.0, base_salary - (unpaid_absences * per_day_rate))

        # Remote Swap Adjustment:
        # Since 'paid_days' includes remote_attendance, the base_payout currently pays them
        # the standard Base Rate for their remote days. We must swap out the Base Rate for
        # the Remote Rate for the exact number of days they worked remotely.
        remote_swap_adjustment = remote_attendance * (remote_per_day - per_day_rate)

        gross_salary = base_payout + remote_swap_adjustment
        return max(0.0, round(gross_salary))

    @classmethod
    def calculate_tds(cls, employee, year, month, gross_salary=None, holidays_override=None, tds_override=None, incentive_override=0, bonus_override=0):
        if tds_override is not None:
            return float(tds_override)

        if gross_salary is None:
            gross_salary = cls.calculate_gross_salary(
                employee=employee, year=year, month=month, holidays_override=holidays_override
            )

        try:
            salary_obj = Salary.objects.get(employee=employee)
        except Salary.DoesNotExist:
            return 0.0

        org = employee.organization
        marital = (getattr(employee, 'marital_status', 'single') or 'single').lower()

        from salary_management.models import SalaryTaxBand, IncentiveTaxBand, BonusTaxBand, get_tax_from_bands
        base_tds = 0.0
        if gross_salary > 0:
            annualized_salary = gross_salary * 12
            if org:
                bands = SalaryTaxBand.objects.filter(organization=org, marital_status=marital)
            else:
                bands = SalaryTaxBand.objects.filter(marital_status=marital)

            if bands.exists():
                base_tds = get_tax_from_bands(bands, annualized_salary) / 12.0
            else:
                tax_rate = salary_obj.tax_rate or 0
                base_tds = round((gross_salary * tax_rate) / 100) if tax_rate > 0 else (salary_obj.tds or 0)

        incentive_tax = 0.0
        if (incentive_override or 0) > 0:
            inc_bands = IncentiveTaxBand.objects.filter(organization=org) if org else IncentiveTaxBand.objects.all()
            if inc_bands.exists():
                incentive_tax = get_tax_from_bands(inc_bands, incentive_override)

        bonus_tax = 0.0
        if (bonus_override or 0) > 0:
            bon_bands = BonusTaxBand.objects.filter(organization=org) if org else BonusTaxBand.objects.all()
            if bon_bands.exists():
                bonus_tax = get_tax_from_bands(bon_bands, bonus_override)

        return round(base_tds + incentive_tax + bonus_tax, 2)

    @classmethod
    def calculate_net_salary(cls, employee, year, month, holidays_override=None, ssf_override=None, epf_override=None, tds_override=None, incentive_override=0, bonus_override=0):
        gross_salary = cls.calculate_gross_salary(
            employee=employee, year=year, month=month, holidays_override=holidays_override)
        if gross_salary <= 0:
            return 0.0

        try:
            salary_obj = Salary.objects.get(employee=employee)
            tds_amount = cls.calculate_tds(
                employee=employee,
                year=year,
                month=month,
                gross_salary=gross_salary,
                holidays_override=holidays_override,
                tds_override=tds_override,
                incentive_override=incentive_override,
                bonus_override=bonus_override,
            )

            ssf = ssf_override if ssf_override is not None else (salary_obj.ssf or 0)
            epf = epf_override if epf_override is not None else (salary_obj.epf or 0)
            cit = salary_obj.citizen_investment_trust or 0
            insurance = salary_obj.insurance or 0
            total_deductions = tds_amount + ssf + epf + cit + insurance
            net = max(0.0, gross_salary - total_deductions)
        except Exception:
            net = gross_salary
        return round(net)


class SalaryTransaction(SoftDeleteModel):
    organization = models.ForeignKey(
        Organization, on_delete=models.SET_NULL, null=True)
    salary = models.ForeignKey(
        Salary, on_delete=models.SET_NULL, null=True, verbose_name='Employee')
    fiscal_year = models.ForeignKey(
        FiscalYear, on_delete=models.CASCADE, null=True, blank=False)
    date = NepaliDateField(null=True)
    content = CKEditor5Field(null=True, blank=True, config_name='extends')
    status = models.BooleanField(default=True, null=True)

    def __str__(self) -> str:
        try:
            return f'{self.salary.employee.user.full_name}'
        except Exception:
            return f'SalaryTransaction #{self.id}'

    manual_net_salary = models.FloatField(null=True, blank=True, verbose_name="Manually Entered Net Salary")
    incentive = models.FloatField(default=0, null=True, blank=True, verbose_name='Incentive')
    bonus = models.FloatField(default=0, null=True, blank=True, verbose_name='Bonus')
    total_expense = models.FloatField(null=True, blank=True, verbose_name='Total Expense (Employer Cost)')

    stored_net_salary = models.FloatField(null=True, blank=True)
    stored_holidays = models.IntegerField(null=True, blank=True)
    stored_no_of_days_present = models.FloatField(null=True, blank=True)
    stored_paid_leaves = models.FloatField(null=True, blank=True)
    stored_unpaid_leaves = models.FloatField(null=True, blank=True)
    stored_half_leaves = models.FloatField(null=True, blank=True)
    transaction_ssf = models.FloatField(default=None, null=True, blank=True)
    transaction_epf = models.FloatField(default=None, null=True, blank=True)
    transaction_tds = models.FloatField(default=None, null=True, blank=True)

    def save(self, *args, **kwargs):
        if self.date and self.salary and getattr(self.salary, 'employee', None):
            if self.stored_holidays is None:
                self.stored_holidays = self.calc_holidays()
            if self.stored_no_of_days_present is None:
                self.stored_no_of_days_present = self.calc_no_of_days_present()
            if self.stored_paid_leaves is None:
                self.stored_paid_leaves = self.calc_paid_leaves()
            if self.stored_unpaid_leaves is None:
                self.stored_unpaid_leaves = self.calc_unpaid_leaves()
            if self.stored_half_leaves is None:
                self.stored_half_leaves = self.calc_half_leaves()
            if self.transaction_tds is None:
                self.transaction_tds = Salary.calculate_tds(
                    employee=self.salary.employee,
                    year=self.date.year,
                    month=self.date.month,
                    holidays_override=self.stored_holidays,
                    tds_override=None,
                    incentive_override=self.incentive or 0,
                    bonus_override=self.bonus or 0,
                )
            if self.transaction_ssf is None:
                self.transaction_ssf = self.salary.ssf or 0
            if self.transaction_epf is None:
                self.transaction_epf = self.salary.epf or 0
            if self.stored_net_salary is None:
                self.stored_net_salary = self.calc_net_salary()
            # Compute total employer expense: net + tds + ssf + epf + cit + insurance
            if self.total_expense is None and self.salary:
                net = self.stored_net_salary or 0
                tds = self.transaction_tds if self.transaction_tds is not None else 0
                ssf = self.transaction_ssf if self.transaction_ssf is not None else (self.salary.ssf or 0)
                epf = self.transaction_epf if self.transaction_epf is not None else (self.salary.epf or 0)
                cit = self.salary.citizen_investment_trust or 0
                insurance = self.salary.insurance or 0
                self.total_expense = round(net + tds + ssf + epf + cit + insurance)
        super().save(*args, **kwargs)

    def calc_net_salary(self):
        if self.manual_net_salary is not None:
            # The manual net salary from the frontend already includes the incentive
            return self.manual_net_salary
        if not self.salary or not getattr(self.salary, 'employee', None) or not self.date:
            return 0
        try:
            net_salary = Salary.calculate_net_salary(
                employee=self.salary.employee, year=self.date.year, month=self.date.month,
                holidays_override=self.stored_holidays,
                ssf_override=self.transaction_ssf,
                epf_override=self.transaction_epf,
                tds_override=self.transaction_tds,
                incentive_override=self.incentive or 0,
                bonus_override=self.bonus or 0)
            return net_salary + (self.incentive or 0) + (self.bonus or 0)
        except Exception:
            return 0

    @property
    def net_salary(self):
        if self.stored_net_salary is not None:
            return self.stored_net_salary
        return self.calc_net_salary()

    def calc_holidays(self):
        if not self.salary or not getattr(self.salary, 'employee', None) or not self.date:
            return 0
        try:
            employee = self.salary.employee
            org = getattr(employee, 'organization', None)
            year, month = self.date.year, self.date.month
            days_in_month = total_days_in_month(year, month)
            joined_year, joined_month, joined_day = Salary.get_employee_joining_bs(employee)
            start_day = 1
            if joined_year:
                if year < joined_year or (year == joined_year and month < joined_month):
                    return 0
                if year == joined_year and month == joined_month:
                    start_day = max(1, min(joined_day, days_in_month))
            return count_saturdays(year, month, start_day=start_day) + (
                count_holidays(org, year, month, start_day=start_day) if org else 0
            )
        except Exception:
            return 0

    @property
    def holidays(self):
        if self.stored_holidays is not None:
            return self.stored_holidays
        return self.calc_holidays()

    def calc_no_of_days_present(self):
        if not self.salary or not getattr(self.salary, 'employee', None) or not self.date:
            return 0
        try:
            return Attendance.get_no_of_present_days(
                self.salary.employee, self.date.year, self.date.month)
        except Exception:
            return 0

    @property
    def no_of_days_present(self):
        if self.stored_no_of_days_present is not None:
            return self.stored_no_of_days_present
        return self.calc_no_of_days_present()

    def calc_paid_leaves(self):
        if not self.salary or not getattr(self.salary, 'employee', None) or not self.date:
            return 0
        try:
            return LeaveRequest.get_total_paid_leaves(
                self.salary.employee, self.date.year, self.date.month)
        except Exception:
            return 0

    @property
    def paid_leaves(self):
        if self.stored_paid_leaves is not None:
            return self.stored_paid_leaves
        return self.calc_paid_leaves()

    def calc_unpaid_leaves(self):
        if not self.salary or not getattr(self.salary, 'employee', None) or not self.date:
            return 0
        try:
            return LeaveRequest.get_total_unpaid_leaves(
                self.salary.employee, self.date.year, self.date.month)
        except Exception:
            return 0

    @property
    def unpaid_leaves(self):
        if self.stored_unpaid_leaves is not None:
            return self.stored_unpaid_leaves
        return self.calc_unpaid_leaves()

    def calc_half_leaves(self):
        if not self.salary or not getattr(self.salary, 'employee', None) or not self.date:
            return 0
        try:
            return LeaveRequest.get_total_half_leaves(
                self.salary.employee, self.date.year, self.date.month)
        except Exception:
            return 0

    @property
    def half_leaves(self):
        if self.stored_half_leaves is not None:
            return self.stored_half_leaves
        return self.calc_half_leaves()

    @property
    def gross_salary(self):
        """Gross before incentive and deductions."""
        if self.salary and getattr(self.salary, 'employee', None) and self.date:
            try:
                return Salary.calculate_gross_salary(
                    employee=self.salary.employee,
                    year=self.date.year, month=self.date.month,
                    holidays_override=self.stored_holidays)
            except Exception:
                return 0
        return 0

    @property
    def deduction(self):
        if self.salary and self.salary.basic_salary and self.net_salary:
            return self.salary.basic_salary - self.net_salary
        return 0


class SalaryTransactionReview(models.Model):
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, null=True, blank=True)
    employee = models.ForeignKey(
        Employee, on_delete=models.CASCADE, null=True, blank=True)
    transaction = models.ForeignKey(
        Salary, on_delete=models.CASCADE, null=True, blank=True)
    content = CKEditor5Field(null=True, blank=True, config_name='extends')
    created_at = models.DateField(auto_now_add=True)


# ──────────────────────────────────────────────────────────────
# Tax Band Models (Global Settings / Tax Management)
# ──────────────────────────────────────────────────────────────

class SalaryTaxBand(models.Model):
    """Progressive tax bands for salary income, split by marital status."""
    MARITAL_STATUS_CHOICES = (
        ("single", "Single"),
        ("married", "Married"),
    )
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, related_name="salary_tax_bands"
    )
    marital_status = models.CharField(
        max_length=10, choices=MARITAL_STATUS_CHOICES, default="single"
    )
    min_salary = models.FloatField(default=0)
    max_salary = models.FloatField(null=True, blank=True, help_text="Leave blank for no upper limit")
    tax_percentage = models.FloatField(default=0)
    order = models.IntegerField(default=0, help_text="Lower number = first band")

    class Meta:
        ordering = ["marital_status", "order", "min_salary"]

    def __str__(self):
        upper = f"{self.max_salary}" if self.max_salary else "∞"
        return f"{self.get_marital_status_display()} | {self.min_salary}–{upper} @ {self.tax_percentage}%"


class IncentiveTaxBand(models.Model):
    """Progressive tax bands for Incentive (TDS) amounts."""
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, related_name="incentive_tax_bands"
    )
    min_amount = models.FloatField(default=0)
    max_amount = models.FloatField(null=True, blank=True, help_text="Leave blank for no upper limit")
    tax_percentage = models.FloatField(default=0)
    order = models.IntegerField(default=0)

    class Meta:
        ordering = ["order", "min_amount"]

    def __str__(self):
        upper = f"{self.max_amount}" if self.max_amount else "∞"
        return f"Incentive {self.min_amount}–{upper} @ {self.tax_percentage}%"


class BonusTaxBand(models.Model):
    """Progressive tax bands for Bonus (TDS) amounts."""
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, related_name="bonus_tax_bands"
    )
    min_amount = models.FloatField(default=0)
    max_amount = models.FloatField(null=True, blank=True, help_text="Leave blank for no upper limit")
    tax_percentage = models.FloatField(default=0)
    order = models.IntegerField(default=0)

    class Meta:
        ordering = ["order", "min_amount"]

    def __str__(self):
        upper = f"{self.max_amount}" if self.max_amount else "∞"
        return f"Bonus {self.min_amount}–{upper} @ {self.tax_percentage}%"


def get_tax_from_bands(bands, amount):
    """
    Given a queryset of tax band objects, calculate the progressive (marginal) tax
    for `amount`. Bands should be ordered by their minimum thresholds in ascending order.
    """
    tax = 0.0
    for band in bands:
        min_val = getattr(band, 'min_salary', None)
        if min_val is None:
            min_val = getattr(band, 'min_amount', 0)
            
        max_val = getattr(band, 'max_salary', None)
        if max_val is None:
            max_val = getattr(band, 'max_amount', None)
        
        # If the total amount hasn't even reached this band, we skip it
        if amount <= min_val:
            continue
            
        # Calculate how much of the amount falls strictly within THIS band
        effective_max = max_val if max_val is not None else float('inf')
        taxable_in_band = min(amount, effective_max) - min_val
        
        tax += (taxable_in_band * band.tax_percentage) / 100
        
    return round(tax)


class FinanceAccess(models.Model):
    """
    Grants a dedicated Finance login full payroll, tax band, fiscal year,
    audit report, and financial analytics access for an organization.
    """
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, related_name='finance_users')
    user = models.OneToOneField(
        'authentication.Account', on_delete=models.CASCADE, related_name='finance_access')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'FinanceAccess({self.user.email} — {self.organization})'
