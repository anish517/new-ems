import os
import django
import sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'base.settings')
django.setup()

from notification.models import Notification

count, _ = Notification.objects.all().delete()
print(f"Deleted {count} notifications.")
