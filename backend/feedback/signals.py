from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth import get_user_model

from notification.models import Notification
from feedback.models import Complain

User = get_user_model()


@receiver(post_save, sender=Complain)
def complain_post_notification(sender, instance, created, **kwargs):
    if kwargs.get("raw", False):
        return  # loading a fixture (loaddata): no side effects
    if not created:
        return

    # If the complain was submitted by a superadmin with no organization/owner, skip notifications or handle gracefully.
    admin_users = []
    if instance.organization:
        admin_users = list(instance.organization.admin_users.all())
    
    # Also include superadmins who might not be explicitly assigned to the organization
    superadmins = list(User.objects.filter(is_superuser=True))
    all_admins = list(set(admin_users + superadmins))

    if instance.owner and instance.owner.user:
        Notification.objects.create(
            user=instance.owner.user,
            title='A new complain was posted',
            message='Your complain has been submitted successfully.',
            is_read=False
        )

    for user in all_admins:
        Notification.objects.create(
            user=user,
            title='A new complain was posted',
            message='A new complain was posted in your organization.',
            is_read=False,
        )

# NOTE: ComplainReply notifications (DB + FCM push) are handled in
# notification/signals.py → on_complain_reply_saved to avoid duplicate
# DB records and to ensure FCM push is sent in one place.
