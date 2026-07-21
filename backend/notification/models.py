from django.contrib.auth.models import User
from django.db import models
from django.contrib.auth import get_user_model

# Create your models here.

User = get_user_model()


class Notification(models.Model):
    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='notifications', db_index=True, null=True)
    title = models.CharField(max_length=500)
    message = models.TextField(max_length=500)
    is_read = models.BooleanField(null=True, blank=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    def __str__(self):
        return self.title

    class Meta:
        indexes = [
            models.Index(fields=['user', 'created_at']),
        ]
