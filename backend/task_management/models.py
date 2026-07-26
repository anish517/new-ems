import os
from django.db import models
from django.db.models.query import QuerySet
from django_ckeditor_5.fields import CKEditor5Field
from nepali_datetime_field.models import NepaliDateField

from organization.models import Employee, Organization
from utils.models import SoftDeleteModel
# Create your models here.


class Project(SoftDeleteModel):
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, null=True)
    title = models.CharField(max_length=255, null=True)
    abbreviation = models.CharField(max_length=255, null=True)
    description = CKEditor5Field(null=True, blank=True, config_name='extends')
    created_by = models.ForeignKey(
        Employee, on_delete=models.SET_NULL, null=True)
    created_at = NepaliDateField()
    updated_at = NepaliDateField()

    def __str__(self) -> str:
        return self.title

    def get_tasks(self):
        return self.tasks.all()

    def get_team_members(self) -> QuerySet[Employee]:
        tasks = self.tasks.all()
        employee_ids = set()

        # Collect unique employee IDs from different task fields
        employee_ids = set(
            tasks.values_list('created_by_id', flat=True).filter(
                created_by_id__isnull=False)
        ) | set(
            tasks.values_list('updated_by_id', flat=True).filter(
                updated_by_id__isnull=False)
        ) | set(
            tasks.values_list('assigned_to_id', flat=True).filter(
                assigned_to_id__isnull=False)
        )
        return Employee.objects.filter(id__in=employee_ids)

    def get_completed_tasks(self):
        return self.tasks.filter(status='done')

    def get_pending_task(self):
        return self.tasks.filter(status='to-do')

    def get_on_going_tasks(self):
        return self.tasks.filter(status='in-progress')

    def completion(self):
        total_tasks = self.tasks.all()
        completed_tasks = total_tasks.filter(status='done')

        if total_tasks.count() == completed_tasks.count():
            return 100
        else:
            percentage = (completed_tasks.count()/total_tasks.count()) * 100
            return round(percentage)


class ProjectFile(models.Model):
    project = models.ForeignKey(
        Project, on_delete=models.CASCADE, null=True, related_name='files')
    title = models.CharField(max_length=255, null=True)
    file = models.FileField()

    def __str__(self) -> str:
        return f'{self.title}'

    def delete(self, *args, **kwargs):
        if self.file:
            if os.path.isfile(self.file.path):
                os.remove(self.file.path)
        super().delete(*args, **kwargs)

    class Meta:
        verbose_name = 'Project file'
        verbose_name_plural = 'Project files'


class Task(SoftDeleteModel):
    STATUS_CHOICES = (
        ('to-do', 'To Do'),
        ('in-progress', 'In Progress'),
        ('done', 'Done'),
    )
    PRIORITY_CHOICES = (
        ('high', 'High'),
        ('medium', 'Medium'),
        ('low', 'Low'),
    )
    project = models.ForeignKey(
        Project, on_delete=models.CASCADE, related_name='tasks', null=True)
    created_by = models.ForeignKey(
        Employee, on_delete=models.CASCADE, null=True, related_name='created_tasks')
    updated_by = models.ForeignKey(
        Employee, on_delete=models.SET_NULL, null=True, related_name='updated_tasks')
    assigned_to = models.ForeignKey(
        Employee, on_delete=models.CASCADE, null=True, related_name='assigned_tasks')
    title = models.CharField(max_length=255, null=True)
    description = CKEditor5Field(null=True, blank=True, config_name='extends')
    status = models.CharField(
        max_length=255, choices=STATUS_CHOICES, null=True, default='to-do')
    priority = models.CharField(
        max_length=255, choices=PRIORITY_CHOICES, null=True, default='low')
    created_at = NepaliDateField(null=True)
    updated_at = NepaliDateField(null=True)
    planned_start_date = NepaliDateField()
    planned_end_date = NepaliDateField()
    actual_start_date = NepaliDateField(null=True)
    actual_end_date = NepaliDateField(null=True)

    def __str__(self) -> str:
        return self.title

    def days_before_deadline(self):

        return self.planned_start_date - self.planned_end_date


class TaskFile(models.Model):
    task = models.ForeignKey(
        Task, on_delete=models.CASCADE, related_name='files', null=True)
    title = models.CharField(max_length=255, null=True)
    file = models.FileField()

    def __str__(self) -> str:
        return self.title
