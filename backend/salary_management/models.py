import nepali_datetime
from django.db import models
from nepali_datetime_field.models import NepaliDateField
from django_ckeditor_5.fields import CKEditor5Field

from attendance.models import Attendance
from fiscal_year.models import FiscalYear
from organization.models import Employee, Organization
from leave_management.models import LeaveRequest
from calendar_app.utilities import count_saturdays, count_holidays, total_days_in_month

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


class Salary(models.Model):
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

    def __str__(self) -> str:
        return f'{self.employee.user.full_name}'

    @staticmethod
    def calculate_gross_salary(employee: Employee, year: int, month: int):
        organization = employee.organization

        basic_salary_per_day = Salary.objects.get(
            employee=employee).basic_salary / 30
        remote_salary_per_day = Salary.objects.get(
            employee=employee).remote_salary / 30

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

        holidays = count_saturdays(year=year, month=month) + count_holidays(
            organization, year=year, month=month)

        remote_salary = remote_attendance * remote_salary_per_day
        basic_salary = site_attendance * basic_salary_per_day

        paid_holidays = paid_leaves + holidays
        gross_salary = remote_salary + basic_salary + \
            (paid_holidays * basic_salary_per_day)
        return round(gross_salary)

    @staticmethod
    def calculate_net_salary(employee: Employee, year: int, month: int):

        # assuming 1% tax on basic salary
        tax = Salary.calculate_gross_salary(
            employee=employee, year=year, month=month) * 0.01
        gross_salary = Salary.calculate_gross_salary(
            employee=employee, year=year, month=month)
        net_salary = round(gross_salary - tax)
        return net_salary


class SalaryTransaction(models.Model):
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

    @property
    def net_salary(self):
        net_salary = Salary.calculate_net_salary(
            employee=self.salary.employee, year=self.date.year, month=self.date.month)
        return net_salary

    @property
    def holidays(self):
        return count_saturdays(
            self.date.year, self.date.month) + count_holidays(self.salary.employee.organization, self.date.year, self.date.month)

    @property
    def no_of_days_present(self):
        return Attendance.get_no_of_present_days(
            self.salary.employee, self.date.year, self.date.month)

    @property
    def paid_leaves(self):
        return LeaveRequest.get_total_paid_leaves(
            self.salary.employee, self.date.year, self.date.month)

    @property
    def deduction(self):
        return self.salary.basic_salary - self.net_salary


class SalaryTransactionReview(models.Model):
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, null=True, blank=True)
    employee = models.ForeignKey(
        Employee, on_delete=models.CASCADE, null=True, blank=True)
    transaction = models.ForeignKey(
        Salary, on_delete=models.CASCADE, null=True, blank=True)
    content = CKEditor5Field(null=True, blank=True, config_name='extends')
    created_at = models.DateField(auto_now_add=True)
