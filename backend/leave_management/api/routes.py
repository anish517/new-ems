from django.urls import path
from . import views

urlpatterns = [
    path('leave-requests/', views.LeaveRequestListCreateAPIView.as_view()),
    path('retrieve/<int:id>/', views.RetrieveLeaveRequestApiView.as_view()),
    path('update/<int:pk>/', views.UpdateLeaveRequestApiView.as_view()),
    path('leave-count-detail/<int:employee_id>/',
         views.EmployeeLeaveCountDetailAPIView.as_view()),

    path('leave-type/<int:id>/', views.LeaveTypeRetrieveAPIView.as_view()),
    path('leave-balance/<employee_id>/',
         views.LeaveQuotaRetrieveAPIView.as_view()),
    path('leave-balance/detail/<int:pk>/',
         views.LeaveBalanceDetailAPIView.as_view()),
]
