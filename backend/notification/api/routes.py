from django.urls import path
from . import views

urlpatterns = [
    path('list/', views.NotificationListApiView.as_view()),
    path('api/mark-all-read/', views.MarkAllNotificationsAsReadView.as_view(),
         name='mark-all-notifications-as-read'),
    path('<int:pk>/', views.NotificationRetrieveUpdateDestroyAPIView.as_view()),

]
