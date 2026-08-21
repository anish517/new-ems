import os
from django.db import models
from django.db.models.query import QuerySet
from django_ckeditor_5.fields import CKEditor5Field
from nepali_datetime_field.models import NepaliDateField

from organization.models import Employee, Organization
from utils.models import SoftDeleteModel


class Project(SoftDeleteModel):
    TYPE_CHOICES = [
        ("monthly", "Monthly"),
        ("daily", "Daily"),
        ("hourly", "Hourly"),
    ]
    STATUS_CHOICES = [
        ("ongoing", "Ongoing"),
        ("incomplete", "Incomplete"),
        ("complete", "Complete"),
    ]

    organization = models.ForeignKey(Organization, on_delete=models.CASCADE, null=True)
    title = models.CharField(max_length=255, null=True)
    abbreviation = models.CharField(max_length=255, null=True, blank=True)
    description = CKEditor5Field(null=True, blank=True, config_name="extends")
    project_type = models.CharField(max_length=10, choices=TYPE_CHOICES, default="monthly")
    estimated_hours = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    total_budget = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    status = models.CharField(max_length=12, choices=STATUS_CHOICES, default="ongoing")
    created_by = models.ForeignKey(Employee, on_delete=models.SET_NULL, null=True)
    created_at = NepaliDateField()
    updated_at = NepaliDateField()

    def __str__(self) -> str:
        return self.title or ""

    def get_tasks(self):
        return self.tasks.all()

    def get_team_members(self) -> QuerySet[Employee]:
        tasks = self.tasks.all()
        employee_ids = (
            set(tasks.values_list("created_by_id", flat=True).filter(created_by_id__isnull=False))
            | set(tasks.values_list("updated_by_id", flat=True).filter(updated_by_id__isnull=False))
            | set(tasks.values_list("assigned_to_id", flat=True).filter(assigned_to_id__isnull=False))
        )
        assignment_ids = set(self.assignments.values_list("employee_id", flat=True))
        employee_ids |= assignment_ids
        return Employee.objects.filter(id__in=employee_ids)

    def get_completed_tasks(self):
        return self.tasks.filter(status="done")

    def get_pending_task(self):
        return self.tasks.filter(status="to-do")

    def get_on_going_tasks(self):
        return self.tasks.filter(status="in-progress")

    def completion(self):
        total = self.tasks.count()
        if total == 0:
            return 0
        done = self.tasks.filter(status="done").count()
        return 100 if done == total else round((done / total) * 100)

    def sync_status(self):
        """Auto-flip project status to complete when all tasks are done."""
        total = self.tasks.count()
        if total > 0 and self.tasks.exclude(status="done").count() == 0:
            if self.status != "complete":
                self.status = "complete"
                self.save(update_fields=["status"])


class ProjectAssignment(models.Model):
    ROLE_CHOICES = [("senior", "Senior"), ("junior", "Junior")]
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="assignments")
    employee = models.ForeignKey(Employee, on_delete=models.CASCADE, related_name="project_assignments")
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default="junior")
    hourly_rate = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    daily_rate = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)

    class Meta:
        unique_together = ("project", "employee")

    def __str__(self) -> str:
        return f"{self.employee} — {self.role} on {self.project}"


class ProjectFile(models.Model):
    project = models.ForeignKey(Project, on_delete=models.CASCADE, null=True, related_name="files")
    title = models.CharField(max_length=255, null=True)
    file = models.FileField(upload_to="project_attachments/")

    def __str__(self) -> str:
        return f"{self.title}"

    def delete(self, *args, **kwargs):
        if self.file and os.path.isfile(self.file.path):
            os.remove(self.file.path)
        super().delete(*args, **kwargs)

    class Meta:
        verbose_name = "Project file"
        verbose_name_plural = "Project files"


class Task(SoftDeleteModel):
    STATUS_CHOICES = (("to-do", "To Do"), ("in-progress", "In Progress"), ("done", "Done"))
    PRIORITY_CHOICES = (("high", "High"), ("medium", "Medium"), ("low", "Low"))
    TYPE_CHOICES = (("hourly", "Hourly"), ("daily", "Daily"))

    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="tasks", null=True)
    created_by = models.ForeignKey(Employee, on_delete=models.CASCADE, null=True, related_name="created_tasks")
    updated_by = models.ForeignKey(Employee, on_delete=models.SET_NULL, null=True, related_name="updated_tasks")
    assigned_to = models.ForeignKey(Employee, on_delete=models.CASCADE, null=True, related_name="assigned_tasks")
    title = models.CharField(max_length=255, null=True)
    task_type = models.CharField(max_length=10, choices=TYPE_CHOICES, default="daily")
    description = CKEditor5Field(null=True, blank=True, config_name="extends")
    description_pdf = models.FileField(upload_to="task_description_pdfs/", null=True, blank=True)
    status = models.CharField(max_length=255, choices=STATUS_CHOICES, null=True, default="to-do")
    priority = models.CharField(max_length=255, choices=PRIORITY_CHOICES, null=True, default="low")
    created_at = NepaliDateField(null=True)
    updated_at = NepaliDateField(null=True)
    planned_start_date = NepaliDateField()
    planned_end_date = NepaliDateField()
    actual_start_date = NepaliDateField(null=True)
    actual_end_date = NepaliDateField(null=True)
    rating = models.IntegerField(null=True, blank=True)

    def __str__(self) -> str:
        return self.title or ""

    def days_before_deadline(self):
        return self.planned_start_date - self.planned_end_date

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        if self.project_id:
            self.project.sync_status()


class TaskFile(models.Model):
    task = models.ForeignKey(Task, on_delete=models.CASCADE, related_name="files", null=True)
    title = models.CharField(max_length=255, null=True)
    file = models.FileField(upload_to="task_attachments/")

    def __str__(self) -> str:
        return self.title or ""


class TaskProgressReport(models.Model):
    """Trello-style daily progress log. Multiple reports per day per task are allowed."""
    task = models.ForeignKey(Task, on_delete=models.CASCADE, related_name="progress_reports")
    submitted_by = models.ForeignKey(Employee, on_delete=models.SET_NULL, null=True, related_name="progress_reports")
    date = models.DateField()
    description = models.TextField()
    attachment = models.FileField(upload_to="task_progress_attachments/", null=True, blank=True)
    hours_worked = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True)
    days_worked = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_deletion_requested = models.BooleanField(default=False)
    deletion_reason = models.TextField(null=True, blank=True)
    deletion_requested_by = models.ForeignKey(
        Employee, on_delete=models.SET_NULL, null=True, blank=True, related_name="deletion_requested_reports"
    )
    deletion_requested_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return f"Progress on \"{self.task}\" -- {self.date}"

