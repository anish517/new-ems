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
    if kwargs.get("raw", False):
        return  # loading a fixture (loaddata): no side effects
    if instance.pk:
        # Fetch the old instance from the database
        old_instance = sender.objects.get(pk=instance.pk)

        creator_user = instance.created_by.user if (instance.created_by and instance.created_by.user) else None
        assignee_user = instance.assigned_to.user if (instance.assigned_to and instance.assigned_to.user) else None
        updater_user = instance.updated_by.user if (instance.updated_by and instance.updated_by.user) else None

        # Skip self-notifications when an employee updates/moves their own personal card
        if (instance.is_personal or instance.project_id is None) and updater_user and updater_user == creator_user:
            return

        ignored_fields = {"position", "updated_at", "updated_by"}
        # Compare field values and track changes
        changed_fields = {}
        for field in instance._meta.fields:
            field_name = field.name
            if field_name in ignored_fields:
                continue
            old_value = getattr(old_instance, field_name)
            new_value = getattr(instance, field_name)

            if old_value != new_value:
                field_verbose_name = instance._meta.get_field(
                    field_name).verbose_name
                changed_fields[field_verbose_name] = (old_value, new_value)

        # Log or process the changed fields
        if changed_fields:
            updater_name = instance.updated_by.user.full_name if instance.updated_by else "Admin"

            for field_name, value in changed_fields.items():
                if creator_user and creator_user != updater_user:
                    Notification.objects.create(
                        user=creator_user,
                        title=f'{updater_name} updated {sender._meta.verbose_name} "{instance.title}"',
                        message=f'{updater_name} set {field_name} from {value[0]} to {value[1]}',
                        notification_type='task',
                        reference_id=instance.id,
                        is_read=False,
                    )
                if updater_user and updater_user != creator_user and updater_user != assignee_user:
                    Notification.objects.create(
                        user=updater_user,
                        title=f'You updated {sender._meta.verbose_name} "{instance.title}"',
                        message=f'You set {field_name} from {value[0]} to {value[1]}',
                        notification_type='task',
                        reference_id=instance.id,
                        is_read=False
                    )


@receiver(post_save, sender=Task)
def update_timestamps(sender, instance, created, **kwargs):
    if kwargs.get("raw", False):
        return  # loading a fixture (loaddata): no side effects
    if created:
        creator_user = instance.created_by.user if (instance.created_by and instance.created_by.user) else None
        assignee_user = instance.assigned_to.user if (instance.assigned_to and instance.assigned_to.user) else None

        # Never notify an employee for creating/assigning their own card
        if creator_user and assignee_user and creator_user == assignee_user:
            return

        creator_name = creator_user.full_name if creator_user else "Admin"

        if assignee_user and assignee_user != creator_user:
            Notification.objects.create(
                user=assignee_user,
                title=f'{creator_name} added new Task "{instance.title}"',
                message=f'A new task was assigned to {assignee_user.full_name} by {creator_name}',
                notification_type='task',
                reference_id=instance.id,
                is_read=False
            )

        if creator_user and creator_user != assignee_user:
            assigned_name = assignee_user.full_name if assignee_user else "someone"
            Notification.objects.create(
                user=creator_user,
                title=f'You added new Task "{instance.title}"',
                message=f'You assigned a new task to {assigned_name}',
                notification_type='task',
                reference_id=instance.id,
                is_read=False
            )
