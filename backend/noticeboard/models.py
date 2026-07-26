from django.db import models
from django_ckeditor_5.fields import CKEditor5Field
from nepali_datetime_field.models import NepaliDateField
from organization.models import Organization, Employee
from utils.models import SoftDeleteModel

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