import datetime
from django.core.management.base import BaseCommand
import nepali_datetime
from calendar_app.models import Event
from employee.models import Employee
from notification.fcm import notify_user

class Command(BaseCommand):
    help = 'Sends FCM push notifications for upcoming calendar events'

    def handle(self, *args, **kwargs):
        now_np = nepali_datetime.date.today()
        
        # We need to find dates 1 day ahead and 6 days ahead in Nepali calendar
        one_day_ahead = now_np + datetime.timedelta(days=1)
        six_days_ahead = now_np + datetime.timedelta(days=6)

        # Process important events (6 days before)
        important_events = Event.objects.filter(start=six_days_ahead, is_important=True)
        for event in important_events:
            self._notify_org_users(event, days=6)

        # Process regular events (1 day before)
        regular_events = Event.objects.filter(start=one_day_ahead, is_important=False)
        for event in regular_events:
            self._notify_org_users(event, days=1)
            
        self.stdout.write(self.style.SUCCESS('Successfully sent event reminders'))

    def _notify_org_users(self, event, days):
        # Find all active employees in the organization
        employees = Employee.objects.filter(
            post__department__organization=event.organization, 
            is_active=True
        )
        
        for emp in employees:
            if emp.user:
                notify_user(
                    user=emp.user,
                    title='📅 Upcoming Event Reminder',
                    body=f'"{event.title}" is coming up in {days} day{"s" if days > 1 else ""}.',
                    notification_type='calendar',
                    reference_id=event.id,
                )
