import os
import django
import sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'base.settings')
django.setup()

from django.test import RequestFactory
from notification.api.views import NotificationListApiView
from django.contrib.auth import get_user_model

User = get_user_model()
user = User.objects.filter(email='uuu@gmail.com').first()

if user:
    factory = RequestFactory()
    request = factory.get('/api/notifications/list/')
    request.user = user
    view = NotificationListApiView.as_view()
    response = view(request)
    print("Response Data:", response.data)
else:
    print("User not found.")
