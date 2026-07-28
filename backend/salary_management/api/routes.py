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

    # Tax Band endpoints
    path('tax-bands/salary/', views.SalaryTaxBandListCreateView.as_view(), name='salary-tax-bands'),
    path('tax-bands/salary/<int:pk>/', views.SalaryTaxBandDetailView.as_view(), name='salary-tax-band-detail'),
    path('tax-bands/incentive/', views.IncentiveTaxBandListCreateView.as_view(), name='incentive-tax-bands'),
    path('tax-bands/incentive/<int:pk>/', views.IncentiveTaxBandDetailView.as_view(), name='incentive-tax-band-detail'),
    path('tax-bands/bonus/', views.BonusTaxBandListCreateView.as_view(), name='bonus-tax-bands'),
    path('tax-bands/bonus/<int:pk>/', views.BonusTaxBandDetailView.as_view(), name='bonus-tax-band-detail'),
]
