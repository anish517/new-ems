from nepali_datetime_field.models import NepaliDateField
from django_ckeditor_5.fields import CKEditor5Field
from django.db import models

from organization.models import Employee, Organization

# Create your models here.


class Contract(models.Model):
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, null=True, blank=True)
    employee = models.ForeignKey(
        Employee, on_delete=models.CASCADE, related_name='contract', null=True, blank=True)
    responsibilites = CKEditor5Field(
        null=True, blank=True, config_name="extends")
    start_date = NepaliDateField(null=True)
    end_date = NepaliDateField(null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.employee.user.full_name

    class Meta:
        app_label = 'employee'
