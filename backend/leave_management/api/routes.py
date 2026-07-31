from django.urls import path
from . import views

urlpatterns = [
    path('leave-requests/', views.LeaveRequestListCreateAPIView.as_view()),
    path('retrieve/<int:id>/', views.RetrieveLeaveRequestApiView.as_view()),
    path('update/<int:pk>/', views.UpdateLeaveRequestApiView.as_view()),
    path('leave-count-detail/<int:employee_id>/',
         views.EmployeeLeaveCountDetailAPIView.as_view()),

    path('leave-type/<int:id>/', views.LeaveTypeRetrieveAPIView.as_view()),

    # Employee / Admin: get leave balance for a specific employee
    path('leave-balance/<employee_id>/',
         views.LeaveQuotaRetrieveAPIView.as_view()),

    # Admin: update quota for a specific LeaveBalance record
    path('leave-balance/update/<int:pk>/',
         views.LeaveBalanceUpdateAPIView.as_view()),

    # Legacy detail endpoint
    path('leave-balance/detail/<int:pk>/',
         views.LeaveBalanceDetailAPIView.as_view()),

    # Admin: summary of ALL employees' balances
    path('leave-summary/', views.AllEmployeeLeaveSummaryView.as_view()),
]
