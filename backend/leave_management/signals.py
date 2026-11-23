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
    if kwargs.get("raw", False):
        return  # loading a fixture (loaddata): no side effects
    if created:
        return  # Only care about updates

    # We need the previous state to detect transitions.
    # Strategy: recompute from scratch — sum all approved leaves.
    employee = instance.employee
    if not employee:
        return

    target_type = instance.type
    if target_type:
        lb = LeaveBalance.objects.filter(employee=employee, leave_type=target_type).first()
    else:
        leave_type_name = 'Casual Leave' if instance.is_paid else 'Unpaid Leave'
        lb = LeaveBalance.objects.filter(
            employee=employee,
            leave_type__name__icontains=leave_type_name
        ).first()

    if not lb:
        return

    # Recompute total from all approved paid leaves of this type for this employee
    approved_requests = LeaveRequest.objects.filter(
        employee=employee,
        is_approved=True,
        is_reviewed=True,
        is_paid=True,
    )
    if target_type:
        approved_requests = approved_requests.filter(type=target_type)

    total_taken = sum(lr.no_days for lr in approved_requests)

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
    if kwargs.get("raw", False):
        return  # loading a fixture (loaddata): no side effects
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
    if kwargs.get("raw", False):
        return  # loading a fixture (loaddata): no side effects
    if not instance.organization:
        return
    employees = instance.organization.employees
    for employee in employees:
        LeaveBalance.objects.filter(employee=employee, leave_type=instance).delete()


# Leave notifications are handled centrally in notification/signals.py
# (_connect_leave_signals) to send both in-app DB notifications and FCM
# push notifications without creating duplicate records.
