"""
Django signals for automatic push notifications.
Fires when tasks/leaves/performance/feedback are created or updated.
"""
from django.db.models.signals import post_save
from django.dispatch import receiver


# ── Task notifications ──────────────────────────────────────────────────────
def _connect_task_signals():
    try:
        from task_management.models import Task
        from notification.fcm import notify_user

        @receiver(post_save, sender=Task)
        def on_task_saved(sender, instance, created, **kwargs):
            if not instance.assigned_to:
                return
            if created:
                notify_user(
                    user=instance.assigned_to.user,
                    title='📋 New Task Assigned',
                    body=f'You have been assigned: "{instance.title}"',
                    notification_type='task',
                    reference_id=instance.id,
                )
            elif instance.status == 'done' and instance.created_by:
                notify_user(
                    user=instance.created_by.user,
                    title='✅ Task Completed',
                    body=f'"{instance.title}" has been marked done.',
                    notification_type='task',
                    reference_id=instance.id,
                )
    except Exception as e:
        print(f'[Signals] Could not connect task signals: {e}')


# ── Leave notifications ──────────────────────────────────────────────────────
def _connect_leave_signals():
    try:
        from leave_management.models import LeaveRequest
        from notification.fcm import notify_user

        @receiver(post_save, sender=LeaveRequest)
        def on_leave_saved(sender, instance, created, **kwargs):
            if created:
                notify_user(
                    user=instance.employee.user,
                    title='🗓️ Leave Request Submitted',
                    body=f'Your leave request "{instance.subject}" is pending approval.',
                    notification_type='leave',
                    reference_id=instance.id,
                )
            elif instance.is_reviewed:
                status_str = 'approved ✅' if instance.is_approved else 'rejected ❌'
                notify_user(
                    user=instance.employee.user,
                    title=f'Leave Request {status_str.split()[0].capitalize()}',
                    body=f'Your leave request "{instance.subject}" has been {status_str}.',
                    notification_type='leave',
                    reference_id=instance.id,
                )
    except Exception as e:
        print(f'[Signals] Could not connect leave signals: {e}')



# ── Performance notifications ────────────────────────────────────────────────
def _connect_performance_signals():
    try:
        from performance.models import PerformanceReview
        from notification.fcm import notify_user

        @receiver(post_save, sender=PerformanceReview)
        def on_performance_saved(sender, instance, created, **kwargs):
            if created and hasattr(instance, 'employee') and instance.employee:
                notify_user(
                    user=instance.employee.user,
                    title='⭐ New Performance Review',
                    body='A new performance review has been submitted for you.',
                    notification_type='performance',
                    reference_id=instance.id,
                )
    except Exception as e:
        print(f'[Signals] Could not connect performance signals: {e}')


# ── Feedback notifications ───────────────────────────────────────────────────
def _connect_feedback_signals():
    pass

def connect_all_signals():
    _connect_task_signals()
    _connect_leave_signals()
    _connect_performance_signals()
    _connect_feedback_signals()

