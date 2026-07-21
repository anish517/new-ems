from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth import get_user_model

from notification.models import Notification
from noticeboard.models import Notice
from organization.models import Employee

User = get_user_model()

@receiver(post_save, sender=Notice)
def notice_post_notification(sender, instance, created, **kwargs):
    if not created:
        return

    if instance.organization:
        # Notify all employees in the organization
        employees = Employee.objects.filter(post__department__organization=instance.organization)
    else:
        # Global notice: notify all employees across all organizations
        employees = Employee.objects.all()

    for emp in employees:
        if emp.user:
            Notification.objects.create(
                user=emp.user,
                title='New Notice',
                message=f'A new notice has been posted: {instance.title}',
                is_read=False
            )
