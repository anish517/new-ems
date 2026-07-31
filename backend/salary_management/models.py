import nepali_datetime
from django.db import models
from nepali_datetime_field.models import NepaliDateField
from django_ckeditor_5.fields import CKEditor5Field

from attendance.models import Attendance
from fiscal_year.models import FiscalYear
from organization.models import Employee, Organization
from leave_management.models import LeaveRequest
from calendar_app.utilities import count_saturdays, count_holidays, total_days_in_month
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
    def calculate_gross_salary(employee: Employee, year: int, month: int, holidays_override=None):
        organization = employee.organization

        days_in_month = total_days_in_month(year, month)

        attendances = Attendance.get_attendance_of_selected_month(
            employee=employee, year=year, month=month)

        days_present = [
            attendance for attendance in attendances if attendance.has_checked_in()]

        remote_attendance = len([
            attendance for attendance in days_present if attendance.is_remote])
        site_attendance = len([
            attendance for attendance in days_present if not attendance.is_remote])

        paid_leaves = LeaveRequest.get_total_paid_leaves(
            employee=employee, year=year, month=month)

        if holidays_override is not None:
            holidays = holidays_override
        else:
            holidays = count_saturdays(year=year, month=month) + count_holidays(
                organization, year=year, month=month)

        # 30-Day Basis Calculation
        per_day_rate = Salary.objects.get(employee=employee).basic_salary / 30.0
        remote_per_day = Salary.objects.get(employee=employee).remote_salary / 30.0

        # Total paid days (they get credit for attendance, paid leaves, and holidays)
        paid_days = site_attendance + remote_attendance + paid_leaves + holidays
        
        # Unpaid Half Leave Loophole Fix:
        # If someone takes an unpaid half leave, but clocks in for the other half, 
        # site_attendance gives them 1.0 full point. We must subtract 0.5 points.
        unpaid_half_leaves = LeaveRequest.objects.filter(
            employee=employee, is_half_day=True, is_paid=False, is_approved=True
        )
        unpaid_half_leave_dates = [
            lr.from_date for lr in unpaid_half_leaves 
            if lr.from_date.year == year and lr.from_date.month == month
        ]
        for attendance in days_present:
            if attendance.date in unpaid_half_leave_dates:
                paid_days -= 0.5
        
        # Calculate unpaid absences by comparing actual days in month to their paid days
        # We use max(0) to ensure we don't accidentally overpay if there's double-counting 
        # (e.g. someone checks in on a holiday)
        unpaid_absences = max(0, days_in_month - paid_days)

        # Start with the full 30-day base salary, and deduct any unpaid absences
        base_salary = Salary.objects.get(employee=employee).basic_salary
        base_payout = base_salary - (unpaid_absences * per_day_rate)
        
        # Remote Swap Adjustment:
        # Since 'paid_days' includes remote_attendance, the base_payout currently pays them 
        # the standard Base Rate for their remote days. We must swap out the Base Rate for 
        # the Remote Rate for exactly the number of days they worked remotely.
        remote_swap_adjustment = remote_attendance * (remote_per_day - per_day_rate)

        gross_salary = base_payout + remote_swap_adjustment
        return round(gross_salary)

    @classmethod
    def calculate_net_salary(cls, employee, year, month, holidays_override=None, ssf_override=None, epf_override=None, tds_override=None, incentive_override=0, bonus_override=0):
        gross_salary = cls.calculate_gross_salary(
            employee=employee, year=year, month=month, holidays_override=holidays_override)
        try:
            salary_obj = Salary.objects.get(employee=employee)

            if tds_override is not None:
                tds_amount = tds_override
            else:
                # Try dynamic tax bands first
                org = employee.organization
                marital = (getattr(employee, 'marital_status', 'single') or 'single').lower()
                
                annualized_salary = (gross_salary * 12)
                
                from salary_management.models import SalaryTaxBand, IncentiveTaxBand, BonusTaxBand, get_tax_from_bands
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
                if incentive_override > 0:
                    inc_bands = IncentiveTaxBand.objects.filter(organization=org) if org else IncentiveTaxBand.objects.all()
                    if inc_bands.exists():
                        incentive_tax = get_tax_from_bands(inc_bands, incentive_override)
                
                bonus_tax = 0.0
                if bonus_override > 0:
                    bon_bands = BonusTaxBand.objects.filter(organization=org) if org else BonusTaxBand.objects.all()
                    if bon_bands.exists():
                        bonus_tax = get_tax_from_bands(bon_bands, bonus_override)
                        
                tds_amount = base_tds + incentive_tax + bonus_tax

            ssf = ssf_override if ssf_override is not None else (salary_obj.ssf or 0)
            epf = epf_override if epf_override is not None else (salary_obj.epf or 0)
            cit = salary_obj.citizen_investment_trust or 0
            insurance = salary_obj.insurance or 0
            total_deductions = tds_amount + ssf + epf + cit + insurance
            net = gross_salary - total_deductions
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
        return f'{self.salary.employee.user.full_name}'

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
        if self.date and self.salary:
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
            if self.stored_net_salary is None:
                self.stored_net_salary = self.calc_net_salary()
            # Compute total employer expense: net + tds + ssf + epf + cit + insurance
            if self.total_expense is None and self.salary:
                net = self.stored_net_salary or 0
                tds = self.transaction_tds if self.transaction_tds is not None else (round((self.gross_salary * (self.salary.tax_rate or 0)) / 100) if (self.salary.tax_rate or 0) > 0 else (self.salary.tds or 0))
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
        net_salary = Salary.calculate_net_salary(
            employee=self.salary.employee, year=self.date.year, month=self.date.month,
            holidays_override=self.stored_holidays,
            ssf_override=self.transaction_ssf,
            epf_override=self.transaction_epf,
            tds_override=self.transaction_tds,
            incentive_override=self.incentive or 0,
            bonus_override=self.bonus or 0)
        return net_salary + (self.incentive or 0) + (self.bonus or 0)

    @property
    def net_salary(self):
        if self.stored_net_salary is not None:
            return self.stored_net_salary
        return self.calc_net_salary()

    def calc_holidays(self):
        return count_saturdays(
            self.date.year, self.date.month) + count_holidays(self.salary.employee.organization, self.date.year, self.date.month)

    @property
    def holidays(self):
        if self.stored_holidays is not None:
            return self.stored_holidays
        return self.calc_holidays()

    def calc_no_of_days_present(self):
        return Attendance.get_no_of_present_days(
            self.salary.employee, self.date.year, self.date.month)

    @property
    def no_of_days_present(self):
        if self.stored_no_of_days_present is not None:
            return self.stored_no_of_days_present
        return self.calc_no_of_days_present()

    def calc_paid_leaves(self):
        return LeaveRequest.get_total_paid_leaves(
            self.salary.employee, self.date.year, self.date.month)

    @property
    def paid_leaves(self):
        if self.stored_paid_leaves is not None:
            return self.stored_paid_leaves
        return self.calc_paid_leaves()

    def calc_unpaid_leaves(self):
        return LeaveRequest.get_total_unpaid_leaves(
            self.salary.employee, self.date.year, self.date.month)

    @property
    def unpaid_leaves(self):
        if self.stored_unpaid_leaves is not None:
            return self.stored_unpaid_leaves
        return self.calc_unpaid_leaves()

    def calc_half_leaves(self):
        return LeaveRequest.get_total_half_leaves(
            self.salary.employee, self.date.year, self.date.month)

    @property
    def half_leaves(self):
        if self.stored_half_leaves is not None:
            return self.stored_half_leaves
        return self.calc_half_leaves()

    @property
    def gross_salary(self):
        """Gross before incentive and deductions."""
        if self.salary and self.date:
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
