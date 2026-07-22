from django.contrib.auth.models import User
from django.db import models
from django.contrib.auth import get_user_model

User = get_user_model()


class Notification(models.Model):
    TYPE_CHOICES = [
        ('task', 'Task'),
        ('leave', 'Leave'),
        ('performance', 'Performance'),
        ('feedback', 'Feedback'),
        ('calendar', 'Calendar'),
        ('general', 'General'),
    ]

    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='notifications', db_index=True, null=True)
    title = models.CharField(max_length=500)
    message = models.TextField(max_length=500)
    notification_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default='general')
    reference_id = models.IntegerField(null=True, blank=True)
    is_read = models.BooleanField(null=True, blank=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    def __str__(self):
        return self.title

    class Meta:
        indexes = [
            models.Index(fields=['user', 'created_at']),
        ]
        ordering = ['-created_at']


class DeviceToken(models.Model):
    """Stores FCM device tokens per user (one user can have multiple devices)."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='device_tokens')
    token = models.TextField(unique=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.user} - {self.token[:20]}...'
