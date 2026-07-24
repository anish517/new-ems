from django.urls import path

from . import views

urlpatterns = [
    path('<int:pk>/', views.AttendanceDetailAPIView.as_view()),
    path('total-working-hour/<int:employee_id>/',
         views.RetrieveTotalWorkingHourAPIView.as_view()),
    path('yearly/<int:employee_id>/',
         views.EmployeeAttendanceAPIView.as_view()),
    path('check-in/', views.CheckIn.as_view(), name='check-in'),
    path('check-out/', views.CheckOut.as_view(), name='check-out'),
    path('today-status/', views.TodayAttendanceStatusAPIView.as_view(), name='today-status'),
    path('list/', views.AttendanceListAPIView.as_view(), name='attendance-list'),

    # Remote work permission management
    path('remote-work-permission/list/',
         views.RemoteWorkPermissionListAPIView.as_view(), name='remote-permission-list'),
    path('remote-work-permission/set/<int:employee_id>/',
         views.AdminSetRemoteWorkPermissionAPIView.as_view(), name='remote-permission-set'),
    path('remote-work-permission/me/',
         views.MyRemoteWorkPermissionAPIView.as_view(), name='remote-permission-me'),
    path('generate-report/', views.GenerateAttendanceReportAPIView.as_view(), name='generate-report'),
]
