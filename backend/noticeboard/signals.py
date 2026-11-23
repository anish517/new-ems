from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth import get_user_model

from notification.models import Notification
from noticeboard.models import Notice
from organization.models import Employee

User = get_user_model()

# Notice notifications are handled centrally in notification/signals.py
# (_connect_noticeboard_signals) to send both in-app DB notifications and FCM
# push notifications without creating duplicate records.
