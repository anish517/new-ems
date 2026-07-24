from django.urls import path
from . import views

urlpatterns = [
    path('salary/', views.BasicSalaryCreateAPIView.as_view()),
    path('salary/<int:pk>/', views.BasicSalaryUpdateAPIView.as_view()),
    path('transactions/', views.SalaryTransactionListAPIView.as_view()),
    path('transactions/<int:pk>/',
         views.SalaryTransactionRetrieveAPIView.as_view()),
    path('transactions/organization/',
         views.OrganizationSalaryTransactionListAPIView.as_view()),
    path('net-salary/<int:salary_id>/',
         views.NetSalaryAPIView.as_view(), name='employee-salary-info'),
    path('generate-report/', views.GenerateSalaryReportAPIView.as_view(), name='generate-report'),
]
