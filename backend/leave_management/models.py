from django.db import models
from nepali_datetime_field.models import NepaliDateField
from django_ckeditor_5.fields import CKEditor5Field
from tinymce.models import HTMLField

from organization.models import Employee, Organization

# Create your models here.


class LeaveType(models.Model):
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, null=True, blank=True)
    name = models.CharField(null=True, max_length=255)
    quota = models.IntegerField(null=True, default=0)

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
        return self.employee.user.full_name


class LeaveRequest(models.Model):
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
    remarks = models.TextField(max_length=5000)
    created_at = NepaliDateField(null=True, blank=True)
    
    is_half_day = models.BooleanField(default=False)
    HALF_DAY_CHOICES = (
        ('First Half', 'First Half'),
        ('Second Half', 'Second Half'),
    )
    half_day_period = models.CharField(max_length=20, choices=HALF_DAY_CHOICES, null=True, blank=True)

    def __str__(self):
        return f'{self.subject}-{self.is_approved}'

    @property
    def owner(self):
        return self.employee

    @property
    def no_days(self):
        if self.is_half_day:
            return 0.5
        return (self.till_date - self.from_date).days + 1

    @property
    def files(self):
        return self.leave_requests.all()

    @staticmethod
    def get_total_paid_leaves(employee: Employee, year: int, month: int):
        leave_requests = LeaveRequest.objects.filter(employee=employee)
        total_days = 0
        for leave_request in leave_requests:
            if leave_request.from_date.year == int(year) and leave_request.from_date.month == int(month):
                if leave_request.is_paid and leave_request.is_approved:
                    total_days += leave_request.no_days

        return total_days

    @staticmethod
    def get_total_unpaid_leaves(employee: Employee, year: int, month: int):
        leave_requests = LeaveRequest.objects.filter(employee=employee)
        total_days = 0
        for leave_request in leave_requests:

            if leave_request.from_date.year == int(year) and leave_request.from_date.month == int(month):
                if not leave_request.is_paid and leave_request.is_approved:
                    total_days += leave_request.no_days

        return total_days

    @staticmethod
    def get_total_half_leaves(employee: Employee, year: int, month: int):
        leave_requests = LeaveRequest.objects.filter(employee=employee, is_half_day=True, is_approved=True)
        total_half_days = 0
        for leave_request in leave_requests:
            if leave_request.from_date.year == int(year) and leave_request.from_date.month == int(month):
                total_half_days += 1
        return total_half_days


class LeaveRequestFiles(models.Model):
    leave_request = models.ForeignKey(
        LeaveRequest, on_delete=models.CASCADE, blank=True, null=True, related_name='files')
    file = models.FileField(upload_to='leave_requests/', null=True, blank=True)
