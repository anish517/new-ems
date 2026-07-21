from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth import get_user_model

from notification.models import Notification
from feedback.models import Complain

User = get_user_model()


@receiver(post_save, sender=Complain)
def complain_post_notification(sender, instance, created, **kwargs):
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

from feedback.models import ComplainReply

@receiver(post_save, sender=ComplainReply)
def complain_reply_post_notification(sender, instance, created, **kwargs):
    if not created:
        return
        
    complain = instance.complain
    is_admin_reply = instance.employee is None

    if is_admin_reply:
        # Admin replied, notify the employee who owns the complain
        if complain.owner and complain.owner.user:
            Notification.objects.create(
                user=complain.owner.user,
                title='New Reply to your Complaint',
                message=f'Administration replied to your complain: "{complain.title}"',
                is_read=False
            )
    else:
        # Employee replied, notify the admins
        admin_users = []
        if instance.organization:
            admin_users = list(instance.organization.admin_users.all())
            
        superadmins = list(User.objects.filter(is_superuser=True))
        all_admins = list(set(admin_users + superadmins))
        
        for user in all_admins:
            Notification.objects.create(
                user=user,
                title='New Reply from Employee',
                message=f'{instance.employee.user.full_name} replied to complain: "{complain.title}"',
                is_read=False
            )
