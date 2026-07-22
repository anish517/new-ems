from apscheduler.schedulers.background import BackgroundScheduler
from django.core.management import call_command
import atexit

def run_reminder_command():
    print("[Scheduler] Running daily calendar event reminders...")
    try:
        call_command('send_event_reminders')
    except Exception as e:
        print(f"[Scheduler] Error running send_event_reminders: {e}")

def start():
    scheduler = BackgroundScheduler(timezone="Asia/Kathmandu")
    # Run once every day at 00:01 (1 minute past midnight)
    scheduler.add_job(
        run_reminder_command, 
        'cron', 
        hour=0, 
        minute=1, 
        id='calendar_reminders_job', 
        replace_existing=True
    )
    scheduler.start()
    print("[Scheduler] Started successfully: Calendar reminders scheduled for 00:01 every day.")
    
    # Shut down scheduler gracefully when Django exits
    atexit.register(lambda: scheduler.shutdown(wait=False))
