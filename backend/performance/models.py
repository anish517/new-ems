from django.db import models
from organization.models import Employee, Organization
from authentication.models import Account
from utils.models import SoftDeleteModel


class PerformanceCategory(models.Model):
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, related_name='performance_categories')
    name = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class PerformanceReview(SoftDeleteModel):
    employee = models.ForeignKey(
        Employee, on_delete=models.CASCADE, related_name='reviews')
    reviewer = models.ForeignKey(
        Account, on_delete=models.SET_NULL, null=True, related_name='given_reviews')
    category = models.ForeignKey(
        PerformanceCategory, on_delete=models.SET_NULL, null=True, blank=True, related_name='reviews')
    score = models.IntegerField(default=5)  # 1–10
    feedback = models.TextField(blank=True, default='')
    suggestion = models.TextField(blank=True, default='')
    reply = models.TextField(blank=True, null=True)
    replied_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Review for {self.employee} — {self.score}/10'
