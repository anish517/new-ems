from django.urls import path
from . import views

urlpatterns = [
    path('list/', views.NotificationListApiView.as_view(), name='notification-list'),
    path('mark-all-read/', views.MarkAllNotificationsAsReadView.as_view(), name='mark-all-notifications-as-read'),
    path('device-token/', views.RegisterDeviceTokenView.as_view(), name='register-device-token'),
    path('<int:pk>/', views.NotificationRetrieveUpdateDestroyAPIView.as_view(), name='notification-detail'),
]
