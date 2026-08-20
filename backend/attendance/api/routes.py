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
    path('today-attendance-status/', views.AdminTodayAttendanceStatusAPIView.as_view(), name='today-attendance-status'),
    path('punctuality-champions/', views.AdminPunctualityChampionsAPIView.as_view(), name='punctuality-champions'),

    # Remote work permission management
    path('remote-work-permission/list/',
         views.RemoteWorkPermissionListAPIView.as_view(), name='remote-permission-list'),
    path('remote-work-permission/set/<int:employee_id>/',
         views.AdminSetRemoteWorkPermissionAPIView.as_view(), name='remote-permission-set'),
    path('remote-work-permission/me/',
         views.MyRemoteWorkPermissionAPIView.as_view(), name='remote-permission-me'),

    # Remote Work Requests
    path('remote-requests/', views.RemoteWorkRequestListCreateAPIView.as_view(), name='remote-requests'),
    path('remote-requests/<int:pk>/action/', views.AdminApproveRejectRemoteWorkAPIView.as_view(), name='remote-request-action'),

    # Attendance Correction Requests
    path('correction-requests/', views.CorrectionRequestListCreateAPIView.as_view(), name='correction-requests'),
    path('correction-requests/<int:pk>/action/', views.AdminCorrectionRequestActionAPIView.as_view(), name='correction-request-action'),

    path('generate-report/', views.GenerateAttendanceReportAPIView.as_view(), name='generate-report'),
]
