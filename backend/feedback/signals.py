from django.db.models.signals import post_save
from django.dispatch import receiver

from notification.models import Notification
from feedback.models import Complain


# NOTE: Complain creation notifications (DB + FCM push to admins) are
# handled centrally in notification/signals.py → on_complain_saved to
# avoid duplicate DB records.  Only the employee confirmation is kept here.

@receiver(post_save, sender=Complain)
def complain_post_notification(sender, instance, created, **kwargs):
    if kwargs.get("raw", False):
        return  # loading a fixture (loaddata): no side effects
    if not created:
        return

    # Confirm to the employee that their complain was submitted
    if instance.owner and instance.owner.user:
        Notification.objects.create(
            user=instance.owner.user,
            title='A new complain was posted',
            message='Your complain has been submitted successfully.',
            is_read=False
        )

# NOTE: ComplainReply notifications (DB + FCM push) are handled in
# notification/signals.py → on_complain_reply_saved to avoid duplicate
# DB records and to ensure FCM push is sent in one place.
