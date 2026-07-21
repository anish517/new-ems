from django.db import models
from django.contrib.auth import get_user_model

from organization.models import Organization
# Create your models here.

User = get_user_model()

class ActivityLog(models.Model):
    organization = models.ForeignKey(Organization, on_delete=models.CASCADE, null=True, blank=True)
    employee = models.CharField(max_length=255, null=True, blank=True)
    action = models.CharField(max_length=500, default='')
    timestamp = models.DateTimeField(auto_now_add=True, null=True, blank=True)


    def __str__(self):
        return f'{self.employee} {self.action}'
    