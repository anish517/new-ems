"""
Django signals for automatic push notifications.

Notification rules:
  - Feedback/Complain → Notify all superadmin users (is_superuser=True)
  - Performance       → Notify the reviewed employee only
  - Noticeboard       → Notify all employees in the organization
  - Leave             → Notify the applying employee + all org admins (admin_users)
  - Task              → Notify the assigned employee; on done notify the creator
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
            if kwargs.get("raw", False):
                return  # loading a fixture (loaddata): no side effects
            creator_user = instance.created_by.user if (instance.created_by and hasattr(instance.created_by, 'user')) else None
            assignee_user = instance.assigned_to.user if (instance.assigned_to and hasattr(instance.assigned_to, 'user')) else None

            if created:
                if assignee_user:
                    notify_user(
                        user=assignee_user,
                        title='📋 New Task Assigned',
                        body=f'You have been assigned: "{instance.title}"',
                        notification_type='task',
                        reference_id=instance.id,
                    )
                if creator_user and creator_user != assignee_user:
                    assignee_name = assignee_user.full_name if assignee_user else "an employee"
                    notify_user(
                        user=creator_user,
                        title='📋 Task Created',
                        body=f'Task "{instance.title}" created and assigned to {assignee_name}.',
                        notification_type='task',
                        reference_id=instance.id,
                    )
            elif instance.status == 'done':
                if creator_user:
                    notify_user(
                        user=creator_user,
                        title='✅ Task Completed',
                        body=f'"{instance.title}" has been marked done.',
                        notification_type='task',
                        reference_id=instance.id,
                    )
                if assignee_user and assignee_user != creator_user:
                    notify_user(
                        user=assignee_user,
                        title='✅ Task Completed',
                        body=f'"{instance.title}" has been marked completed.',
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
            if kwargs.get("raw", False):
                return  # loading a fixture (loaddata): no side effects
            if created:
                # 1. Notify the employee who applied
                if instance.employee and instance.employee.user:
                    notify_user(
                        user=instance.employee.user,
                        title='🗓️ Leave Request Submitted',
                        body=f'Your leave request "{instance.subject}" is pending approval.',
                        notification_type='leave',
                        reference_id=instance.id,
                    )
                # 2. Notify all org admin users that a new leave was requested
                if instance.organization:
                    for admin_user in instance.organization.admin_users.all():
                        emp_name = instance.employee.user.full_name if (instance.employee and instance.employee.user) else "An employee"
                        notify_user(
                            user=admin_user,
                            title='📩 New Leave Request',
                            body=f'{emp_name} has applied for leave: "{instance.subject}".',
                            notification_type='leave',
                            reference_id=instance.id,
                        )
            elif instance.is_initial_approved and not instance.is_reviewed:
                # Notify employee about initial approval
                if instance.employee and instance.employee.user:
                    notify_user(
                        user=instance.employee.user,
                        title='📋 Sick Leave Initial Approved',
                        body=f'Your sick leave request "{instance.subject}" received Initial Approval and is awaiting final review.',
                        notification_type='leave',
                        reference_id=instance.id,
                    )
                # Notify org admins ready for final approval
                if instance.organization:
                    emp_name = instance.employee.user.full_name if (instance.employee and instance.employee.user) else "Employee"
                    for admin_user in instance.organization.admin_users.all():
                        if admin_user != instance.initial_approved_by:
                            notify_user(
                                user=admin_user,
                                title='📋 Sick Leave Ready for Final Approval',
                                body=f'{emp_name}\'s sick leave "{instance.subject}" received initial approval.',
                                notification_type='leave',
                                reference_id=instance.id,
                            )
            elif instance.is_reviewed:
                # Notify employee about their final leave status
                if instance.employee and instance.employee.user:
                    if instance.is_approved:
                        leave_mode = 'paid leave' if instance.is_paid else 'unpaid leave'
                        notify_user(
                            user=instance.employee.user,
                            title='✅ Leave Request Approved',
                            body=f'Your leave request "{instance.subject}" ({instance.no_days} days) has been fully approved as {leave_mode}.',
                            notification_type='leave',
                            reference_id=instance.id,
                        )
                    else:
                        reason_suffix = f' Reason: {instance.rejection_reason}' if instance.rejection_reason else ''
                        notify_user(
                            user=instance.employee.user,
                            title='❌ Leave Request Rejected',
                            body=f'Your leave request "{instance.subject}" was rejected.{reason_suffix}',
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
            if kwargs.get("raw", False):
                return  # loading a fixture (loaddata): no side effects
            if created and hasattr(instance, 'employee') and instance.employee and instance.employee.user:
                notify_user(
                    user=instance.employee.user,
                    title='⭐ New Performance Review',
                    body='A new performance review has been submitted for you.',
                    notification_type='performance',
                    reference_id=instance.id,
                )
    except Exception as e:
        print(f'[Signals] Could not connect performance signals: {e}')


# ── Feedback / Complain notifications ────────────────────────────────────────
def _connect_feedback_signals():
    try:
        from feedback.models import Complain, ComplainReply
        from notification.fcm import notify_user
        from django.contrib.auth import get_user_model
        User = get_user_model()

        @receiver(post_save, sender=Complain)
        def on_complain_saved(sender, instance, created, **kwargs):
            if kwargs.get("raw", False):
                return  # loading a fixture (loaddata): no side effects
            if created:
                # Notify all superadmin users
                superadmins = User.objects.filter(is_superuser=True, is_active=True)
                for admin in superadmins:
                    notify_user(
                        user=admin,
                        title='📢 New Complaint Filed',
                        body=f'A new complaint has been submitted: "{instance.title}".',
                        notification_type='feedback',
                        reference_id=instance.id,
                    )

        @receiver(post_save, sender=ComplainReply)
        def on_complain_reply_saved(sender, instance, created, **kwargs):
            if kwargs.get("raw", False):
                return  # loading a fixture (loaddata): no side effects
            if created and instance.complain and instance.complain.owner and instance.complain.owner.user:
                # Notify the employee who filed the complaint that a reply has been posted
                notify_user(
                    user=instance.complain.owner.user,
                    title='💬 Reply on Your Complaint',
                    body=f'Your complaint "{instance.complain.title}" has received a response.',
                    notification_type='feedback',
                    reference_id=instance.complain.id,
                )
    except Exception as e:
        print(f'[Signals] Could not connect feedback signals: {e}')


# ── Noticeboard notifications ────────────────────────────────────────────────
def _connect_noticeboard_signals():
    try:
        from noticeboard.models import Notice
        from notification.fcm import notify_user
        from organization.models import Employee

        @receiver(post_save, sender=Notice)
        def on_notice_saved(sender, instance, created, **kwargs):
            if kwargs.get("raw", False):
                return  # loading a fixture (loaddata): no side effects
            if created:
                notified_user_ids = set()
                if instance.organization:
                    # Notify ALL active employees in the organization
                    employees = Employee.objects.filter(
                        post__department__organization=instance.organization,
                        is_active=True,
                    ).select_related('user')
                    # Also notify org admin users
                    for admin_user in instance.organization.admin_users.all():
                        if admin_user.id not in notified_user_ids:
                            notified_user_ids.add(admin_user.id)
                            notify_user(
                                user=admin_user,
                                title='📌 New Notice Posted',
                                body=f'New announcement posted: "{instance.title}".',
                                notification_type='notice',
                                reference_id=instance.id,
                            )
                else:
                    # Notify ALL active employees in the entire system
                    employees = Employee.objects.filter(is_active=True).select_related('user')
                    
                for emp in employees:
                    if emp.user and emp.user.id not in notified_user_ids:
                        notified_user_ids.add(emp.user.id)
                        notify_user(
                            user=emp.user,
                            title='📌 New Notice Posted',
                            body=f'New notice: "{instance.title}".',
                            notification_type='notice',
                            reference_id=instance.id,
                        )
    except Exception as e:
        print(f'[Signals] Could not connect noticeboard signals: {e}')


# ── Salary / Payroll notifications ──────────────────────────────────────────
def _connect_salary_signals():
    try:
        from salary_management.models import SalaryTransaction, Salary
        from notification.fcm import notify_user

        @receiver(post_save, sender=SalaryTransaction)
        def on_salary_transaction_saved(sender, instance, created, **kwargs):
            if kwargs.get("raw", False):
                return  # loading a fixture (loaddata): no side effects
            if not instance.salary or not instance.salary.employee or not instance.salary.employee.user:
                return
            emp_user = instance.salary.employee.user
            date_str = str(instance.date) if instance.date else "current period"
            if created:
                # 1. Notify employee about salary payout
                notify_user(
                    user=emp_user,
                    title='💰 Salary Payout Issued',
                    body=f'Your salary disbursement for {date_str} has been processed.',
                    notification_type='salary',
                    reference_id=instance.id,
                )
                # 2. Notify org admins
                if instance.organization:
                    for admin_user in instance.organization.admin_users.all():
                        if admin_user != emp_user:
                            notify_user(
                                user=admin_user,
                                title='💰 Salary Payout Disbursed',
                                body=f'Salary payout for {emp_user.full_name} ({date_str}) has been processed.',
                                notification_type='salary',
                                reference_id=instance.id,
                            )

        @receiver(post_save, sender=Salary)
        def on_salary_saved(sender, instance, created, **kwargs):
            if kwargs.get("raw", False):
                return  # loading a fixture (loaddata): no side effects
            if not created and instance.employee and instance.employee.user:
                notify_user(
                    user=instance.employee.user,
                    title='💼 Base Salary Updated',
                    body=f'Your base salary structure has been updated to NPR {instance.basic_salary or 0:,.2f}.',
                    notification_type='salary',
                    reference_id=instance.id,
                )
    except Exception as e:
        print(f'[Signals] Could not connect salary signals: {e}')


def connect_all_signals():
    _connect_task_signals()
    _connect_leave_signals()
    _connect_performance_signals()
    _connect_feedback_signals()
    _connect_noticeboard_signals()
    _connect_salary_signals()
