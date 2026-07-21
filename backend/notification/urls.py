from django.urls import path
from . import views

app_name = 'notification'

urlpatterns = [
    path('', views.NotificationListView.as_view(), name='notification_list')
]
