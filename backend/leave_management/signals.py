from django.db.models.signals import post_save, pre_delete
from django.dispatch import receiver

from .models import LeaveRequest, LeaveBalance, LeaveType
from notification.models import Notification


@receiver(post_save, sender=LeaveRequest)
def increment_leave_balance(sender, instance, created, **kwargs):
    """
    Fires every time a LeaveRequest is saved (not created).
    When a leave is approved, add no_days to the matching LeaveBalance
    (Paid or Unpaid) for that employee.
    When a leave is de-approved (reversed), subtract it back.
    """
    if created:
        return  # Only care about updates

    # We need the previous state to detect transitions.
    # Strategy: recompute from scratch — sum all approved leaves.
    employee = instance.employee
    if not employee:
        return

    # Determine which leave type name matches
    leave_type_name = 'Paid Leave' if instance.is_paid else 'Unpaid Leave'

    try:
        lb = LeaveBalance.objects.get(
            employee=employee,
            leave_type__name=leave_type_name
        )
    except LeaveBalance.DoesNotExist:
        return  # No balance record — skip silently
    except LeaveBalance.MultipleObjectsReturned:
        lb = LeaveBalance.objects.filter(
            employee=employee,
            leave_type__name=leave_type_name
        ).first()

    # Recompute total from all approved leaves of this type for this employee
    approved_requests = LeaveRequest.objects.filter(
        employee=employee,
        is_approved=True,
        is_reviewed=True,
        is_paid=instance.is_paid,
    ).exclude(pk=instance.pk)  # exclude self, will add below if approved

    total_taken = sum(lr.no_days for lr in approved_requests)
    if instance.is_approved and instance.is_reviewed:
        total_taken += instance.no_days

    lb.leaves_taken = total_taken
    lb.save(update_fields=['leaves_taken'])


@receiver(post_save, sender=LeaveType)
def update_leave_balance(sender, instance, created, **kwargs):
    """
    if new leave type is created:
        LeaveBalance of the corresponding leave type is created for each user
    else:
        Updates employees' leave balance when LeaveType is updated
    """
    if not instance.organization:
        return  # Guard: cannot create balances without an org
    employees = instance.organization.employees
    if created:
        for employee in employees:
            LeaveBalance.objects.get_or_create(
                organization=instance.organization,
                employee=employee,
                leave_type=instance,
                defaults={'quota': instance.quota, 'leaves_taken': 0}
            )
    else:
        for employee in employees:
            leave_balance, _ = LeaveBalance.objects.get_or_create(
                employee=employee, leave_type=instance,
                defaults={'organization': instance.organization, 'quota': instance.quota, 'leaves_taken': 0}
            )
            leave_balance.quota = instance.quota
            leave_balance.save()


@receiver(pre_delete, sender=LeaveType)
def delete_leave_balance(sender, instance, using, **kwargs):
    """
    Deletes all leave balance instances related to the LeaveType instance
    """
    if not instance.organization:
        return
    employees = instance.organization.employees
    for employee in employees:
        LeaveBalance.objects.filter(employee=employee, leave_type=instance).delete()


@receiver(post_save, sender=LeaveRequest)
def send_leave_request_notification(sender, instance, created, **kwargs):
    employee_notification_title = ''
    employee_notification_message = ''
    admin_notification_title = ''
    admin_notification_message = ''

    if created:
        employee_notification_title = 'Leave request sent'
        employee_notification_message = 'Your leave request has been sent.'
        admin_notification_title = 'New leave request received'
        admin_notification_message = f'{instance.employee.user.full_name} has requested for leave.'

    elif instance.is_reviewed and instance.is_approved:
        if instance.is_paid:
            employee_notification_title = 'Leave request approved as paid leave.'
            employee_notification_message = 'Your leave request has been approved as paid leave.'
            admin_notification_title = employee_notification_title
            admin_notification_message = f'Leave requested by {instance.employee.user.full_name} for {instance.no_days} days approved as paid leave.'
        else:
            employee_notification_title = 'Leave request approved as unpaid leave.'
            employee_notification_message = 'Your leave request has been approved as unpaid leave.'
            admin_notification_title = employee_notification_title
            admin_notification_message = f'Leave requested by {instance.employee.user.full_name} for {instance.no_days} days approved as unpaid leave.'
    else:
        employee_notification_title = 'Leave request declined'
        employee_notification_message = 'Your leave request has been declined.'

    employee_notification = Notification.objects.create(
        user=instance.employee.user,
        title=employee_notification_title,
        message=employee_notification_message,
        is_read=False,
    )

    admin_users = instance.organization.admin_users.all()
    for user in admin_users:
        admin_notification = Notification.objects.create(
            user=user,
            title=admin_notification_title,
            message=admin_notification_message,
            is_read=False,
        )
