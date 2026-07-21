import nepali_datetime
from django.db.models.signals import pre_save, post_save
from django.dispatch import receiver
from django.apps import apps
from notification.models import Notification
from .models import Task


@receiver(pre_save, sender=Task)
def track_field_changes(sender, instance, **kwargs):
    """
    Signal to track changes to model fields before saving.
    """
    if instance.pk:
        # Fetch the old instance from the database
        old_instance = sender.objects.get(pk=instance.pk)

        # Compare field values and track changes
        changed_fields = {}
        for field in instance._meta.fields:
            field_name = field.name
            old_value = getattr(old_instance, field_name)
            new_value = getattr(instance, field_name)

            if old_value != new_value:
                field_verbose_name = instance._meta.get_field(
                    field_name).verbose_name
                changed_fields[field_verbose_name] = (old_value, new_value)

        # Log or process the changed fields
        if changed_fields:
            updater_name = instance.updated_by.user.full_name if instance.updated_by else "Admin"
            updater_user = instance.updated_by.user if instance.updated_by else None
            
            for field_name, value in changed_fields.items():
                if instance.created_by:
                    admin_notification = Notification.objects.create(
                        user=instance.created_by.user,
                        title=f'{updater_name} updated {sender._meta.verbose_name} "{instance.title}"',
                        message=f'{updater_name} set {field_name} from {value[0]} to {value[1]}',
                        is_read=False,
                    )
                if updater_user:
                    employee_notification = Notification.objects.create(
                        user=updater_user,
                        title=f'You updated {sender._meta.verbose_name} "{instance.title}"',
                        message=f'You set {field_name} from {value[0]} to {value[1]}',
                        is_read=False
                    )


@receiver(post_save, sender=Task)
def update_timestamps(sender, instance, created, **kwargs):
    if created:
        creator_name = instance.created_by.user.full_name if instance.created_by else "Admin"
        
        if instance.assigned_to:
            employee_notification = Notification.objects.create(
                user=instance.assigned_to.user,
                title=f'{creator_name} added new Task "{instance.title}"',
                message=f'A new task was assigned to {instance.assigned_to.user.full_name} by {creator_name}',
                is_read=False
            )

        if instance.created_by:
            admin_notification = Notification.objects.create(
                user=instance.created_by.user,
                title=f'You added new Task "{instance.title}"',
                message=f'You assigned a new task to {instance.assigned_to.user.full_name if instance.assigned_to else "someone"}',
                is_read=False
            )
