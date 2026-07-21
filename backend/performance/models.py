from django.db import models
from organization.models import Employee
from authentication.models import Account


class PerformanceReview(models.Model):
    employee = models.ForeignKey(
        Employee, on_delete=models.CASCADE, related_name='reviews')
    reviewer = models.ForeignKey(
        Account, on_delete=models.SET_NULL, null=True, related_name='given_reviews')
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
