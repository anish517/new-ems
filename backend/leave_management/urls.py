from django.urls import path

from . import views

app_name = 'leave_management'

urlpatterns = [
    path('admin/', views.AdminDashboard.as_view(), name='admin_dashboard'),
    path('employee/', views.EmployeeDashboard.as_view(), name='employee_dashboard'),
    path('leave-requests/', views.leave_request_list,
         name='leave_request_list'),
    path('leave-requests/create/',
         views.CreateLeaveRequest.as_view(), name='apply_leave'),
    path('leave-requests/<int:pk>/', views.LeaveRequestDetail.as_view(),
         name='leave_request_detail'),
    path('approve-leave-request/<int:leave_request_id>/',
         views.approve_leave_request, name='approve_leave_request'),

    path('leave-balances/', views.LeaveBalanceList.as_view(),
         name='leave_balance_list'),
    path('leave-balances/<int:employee_id>/',
         views.LeaveBalanceUpdateView.as_view(), name='leave_balance_update'),
    path('leave-types/', views.LeaveTypeList.as_view(), name='leave_type_list'),
    path('leave-types/create/', views.CreateLeaveType.as_view(),
         name='create_leave_type'),
    path('leave-types/update/<int:pk>/',
         views.UpdateLeaveType.as_view(), name='update_leave_type'),
]
