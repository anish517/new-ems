from django.db import models
from django_ckeditor_5.fields import CKEditor5Field
from nepali_datetime_field.models import NepaliDateField
from organization.models import Organization, Employee
from utils.models import SoftDeleteModel
from django.contrib.auth import get_user_model

User = get_user_model()

# Create your models here.

class Notice(SoftDeleteModel):
    organization = models.ForeignKey(Organization, on_delete=models.CASCADE, null=True, blank=True)
    created_by = models.ForeignKey(Employee, on_delete=models.CASCADE, null=True, blank=True)
    date = NepaliDateField(null=True, blank=True)
    title = models.CharField(max_length=255)
    description = CKEditor5Field(null=True, blank=True, config_name='extends')
    created_at = NepaliDateField(null=True, blank=True)

class NoticeFile(models.Model):
    notice = models.ForeignKey(Notice, on_delete=models.CASCADE)
    file = models.FileField(upload_to='notice/', blank=True, null=True)

    def delete(self, *args, **kwargs):
        self.file.delete(save=False)
        super().delete(*args, **kwargs)


class CompanyPolicy(SoftDeleteModel):
    """Company policies and rulebook entries. Admins create; employees read."""
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, related_name='policies'
    )
    title = models.CharField(max_length=255)
    content = CKEditor5Field(config_name='extends')
    category = models.CharField(max_length=100, null=True, blank=True,
                                help_text='e.g. HR, IT, General, Security')
    is_active = models.BooleanField(default=True)
    created_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='created_policies'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['category', 'title']
        verbose_name_plural = 'Company Policies'

    def __str__(self):
        return f"{self.title} ({self.organization.name})"