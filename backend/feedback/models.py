import nepali_datetime
from django.db import models
from django_ckeditor_5.fields import CKEditor5Field

from nepali_datetime_field.models import NepaliDateField


from organization.models import Employee, Organization
from utils.models import SoftDeleteModel

# Create your models here.


class ComplainCategory(models.Model):
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, null=True, related_name='complain_categories')

    title = models.CharField(max_length=255, null=True)
    created_at = NepaliDateField(null=True)
    updated_at = NepaliDateField(null=True)

    def __str__(self, *args, **kwargs) -> str:
        return self.title

    def save(self, *args, **kwargs):
        if not self.created_at:
            self.created_at = nepali_datetime.date.today()
            self.updated_at = nepali_datetime.date.today()
        else:
            self.updated_at = nepali_datetime.date.today()

        super().save(*args, **kwargs)

    class Meta:
        verbose_name = 'Category'
        verbose_name_plural = 'Categories'


class Complain(SoftDeleteModel):
    VISIBILITY_CHOICES = (
        ('anonymous', 'Anonymous'),
        ('identified', 'Identified')
    )
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('reviewed', 'Reviewed'),
    )
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, null=True)
    owner = models.ForeignKey(
        Employee, on_delete=models.SET_NULL, null=True)
    title = models.CharField(max_length=255, null=True)
    category = models.ForeignKey(
        ComplainCategory, null=True, on_delete=models.CASCADE)
    description = CKEditor5Field(null=True, blank=True, config_name='extends')
    visibility = models.CharField(
        max_length=255, choices=VISIBILITY_CHOICES, null=True, default='anonymous')
    status = models.CharField(
        max_length=255, choices=STATUS_CHOICES, null=True, default='pending')
    created_at = NepaliDateField()
    updated_at = NepaliDateField()

    def __str__(self):
        return f'{self.title}'

    def is_anonymous(self):
        return self.visibility == 'anonymous'

    def is_updated(self):
        return self.created_at != self.updated_at

    def save(self, *args, **kwargs):
        if not self.created_at:
            self.created_at = nepali_datetime.date.today()
            self.updated_at = nepali_datetime.date.today()
        else:
            self.updated_at = nepali_datetime.date.today()

        super().save(*args, **kwargs)


class ComplainReply(models.Model):
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, null=True)
    employee = models.ForeignKey(
        Employee, on_delete=models.CASCADE, null=True)
    complain = models.ForeignKey(
        Complain, on_delete=models.CASCADE, related_name='replies')
    content = CKEditor5Field(null=True, blank=True, config_name='extends')
    created_at = NepaliDateField()
    updated_at = NepaliDateField()

    class Meta:
        verbose_name = 'Reply'
        verbose_name_plural = 'Replies'

    def is_updated(self):
        return self.created_at != self.updated_at

    def save(self, *args, **kwargs):
        if not self.created_at:
            self.created_at = nepali_datetime.date.today()
            self.updated_at = nepali_datetime.date.today()
        else:
            self.updated_at = nepali_datetime.date.today()

        super().save(*args, **kwargs)
