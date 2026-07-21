from django.urls import path

from attendance.api import routes
from . import views

app_name = 'attendance'

urlpatterns = [
    path('admin/', views.AdminDashboard.as_view(), name='admin_dashboard'),
    path('employee/', views.EmployeeDashboard.as_view(),
         name='employee_dashboard'),

    path('list/', views.attendance_list, name='attendance_list'),
    path('check-in/', views.check_in, name='check-in'),
    path('check-out/', views.check_out, name='check-out'),
    path('check-out/update/<int:id>/',
         views.update_last_check_out, name='update_last_check_out')
]

urlpatterns += routes.urlpatterns
