import os
import django
import sys

# Ensure backend directory is in path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'base.settings')
django.setup()

from notification.models import Notification
from noticeboard.models import Notice
from feedback.models import Complain, ComplainReply

print(f"Total Notices: {Notice.objects.count()}")
print(f"Total Complains: {Complain.objects.count()}")
print(f"Total ComplainReplies: {ComplainReply.objects.count()}")
print(f"Total Notifications: {Notification.objects.count()}")

for n in Notification.objects.all().order_by('-id')[:10]:
    print(f"ID={n.id}, User={n.user.email}, Title={n.title}, Read={n.is_read}")
