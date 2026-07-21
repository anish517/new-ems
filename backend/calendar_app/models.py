from datetime import timedelta
from django.db import models
from nepali_datetime_field.models import NepaliDateField

from organization.models import Organization

# Create your models here.


class Category(models.Model):
    class COLORS_CHOICES(models.TextChoices):
        DANGER = 'danger', 'Red'
        PRIMARY = 'primary', 'Blue'
        WARNING = 'warning', 'Yellow'
        SECONDARY = 'info', 'Light blue'
        SUCCESS = 'success', 'Green'
    organization = models.ForeignKey(
        Organization, null=True, blank=True, on_delete=models.CASCADE)
    name = models.CharField(max_length=255, null=True)
    color = models.CharField(
        max_length=255, choices=COLORS_CHOICES, null=True)

    class Meta:
        verbose_name = 'Category'
        verbose_name_plural = 'Categories'

    def __str__(self):
        return self.name


class Event(models.Model):
    title = models.CharField(max_length=255, null=True)
    description = models.TextField(null=True)
    start = NepaliDateField(null=True)
    end = NepaliDateField(null=True)
    location = models.CharField(max_length=255, null=True)
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, related_name="events", null=True)
    category = models.ForeignKey(
        Category, blank=True, on_delete=models.CASCADE, null=True)
    is_holiday = models.BooleanField(default=False, null=True)

    def __str__(self):
        return self.title

    @property
    def duration(self):
        """Returns the duration of the event in days."""
        no_of_days = 0
        if self.start and self.end:
            current_date = self.start
            while current_date <= self.end:
                if current_date.weekday() != 6:
                    no_of_days += 1
                current_date += timedelta(days=1)
        return no_of_days
