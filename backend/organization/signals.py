import os
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from django.core.files.storage import default_storage

from attendance.models import RemoteWorkPermission
from calendar_app.models import Category, Event
from leave_management.models import LeaveBalance, LeaveType

from .models import Department, Employee, OrganizationFile, Post
from logs.models import ActivityLog


@receiver(post_save, sender=Employee)
def create_employee_post_save_log(sender, instance, created, **kwargs):
    if not created:
        ActivityLog.objects.create(
            organization=instance.organization,
            employee=instance,
            action=f'{instance.user.full_name} updated',
        )
    else:
        ActivityLog.objects.create(
            organization=instance.organization,
            employee=instance,
            action=f'{instance.user.full_name} created',
        )


@receiver(post_delete, sender=Employee)
def create_employee_post_delete_log(sender, instance, **kwargs):
    ActivityLog.objects.create(
        organization=instance.organization,
        action=f'{instance.user.full_name} removed'
    )


@receiver(post_save, sender=Post)
def create_post_create_update_log(sender, instance, created, **kwargs):
    if created:
        ActivityLog.objects.create(
            organization=instance.organization,
            action=f'{instance.title} added'
        )
    else:
        ActivityLog.objects.create(
            organization=instance.organization,
            action=f'{instance.title} updated'
        )


@receiver(post_delete, sender=Post)
def create_post_delete_log(sender, instance, **kwargs):
    ActivityLog.objects.create(
        organization=instance.organization,
        action=f'{instance.title} deleted'
    )


@receiver(post_save, sender=Department)
def create_department_create_update_log(sender, instance, created, **kwargs):
    if created:
        ActivityLog.objects.create(
            organization=instance.organization,
            action=f'{instance.department_name} created'
        )
    else:
        ActivityLog.objects.create(
            organization=instance.organization,
            action=f'{instance.department_name} updated'
        )


@receiver(post_delete, sender=Department)
def create_department_delete_log(sender, instance, **kwargs):
    ActivityLog.objects.create(
        organization=instance.organization,
        action=f'{instance.department_name} deleted'
    )


@receiver(post_delete, sender=OrganizationFile)
def delete_file_on_model_delete(sender, instance, **kwargs):
    if instance.file:
        if hasattr(instance.file, 'path'):
            # Local file storage
            if os.path.isfile(instance.file.path):
                os.remove(instance.file.path)
            else:
                print(f"File does not exist at: {instance.file.path}")
        else:
            default_storage.delete(instance.file.name)


@receiver(post_save, sender=Employee)
def create_leave_quota(sender, instance, created, **kwargs):
    if created:
        leave_types = LeaveType.objects.filter(
            organization=instance.organization)
        for leave_type in leave_types:
            LeaveBalance.objects.create(
                organization=instance.organization,
                employee=instance,
                leave_type=leave_type,
                quota=leave_type.quota,
                leaves_taken=0
            )


@receiver(post_save, sender=Employee)
def create_employee_birthday_event(sender, instance, created, **kwargs):
    if created:
        if instance.date_of_birth:
            category, _ = Category.objects.get_or_create(
                organization=instance.organization,
                name='Birthday',
            )
            Event.objects.create(
                organization=instance.organization,
                title=f"{instance.user.first_name}'s birthday",
                description=f"{instance.user.first_name}'s birthday",
                category=category,
                start=instance.date_of_birth,
                end=instance.date_of_birth
            )


@receiver(post_save, sender=Employee)
def create_remote_attendance_permission(sender, instance, created, **kwargs):
    if created:
        RemoteWorkPermission.objects.get_or_create(
            employee=instance
        )
