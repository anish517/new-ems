from django.urls import path


from . import views

urlpatterns = [
    path('<int:pk>/', views.AttendanceDetailAPIView.as_view()),
    path('total-working-hour/<int:employee_id>/',
         views.RetrieveTotalWorkingHourAPIView.as_view()),
    path('yearly/<int:employee_id>/',
         views.EmployeeAttendanceAPIView.as_view()),
    path("check-in/", views.CheckIn.as_view(), name="check-in"),
    path("check-out/", views.CheckOut.as_view(), name="check-out"),
    path('remote-work-permission/<int:pk>/',
         views.RemoteWorkPermissionRetrieveUpdateAPIView.as_view()),
    path('today-status/', views.TodayAttendanceStatusAPIView.as_view(), name='today-status'),
    path('list/', views.AttendanceListAPIView.as_view(), name='attendance-list'),
]
