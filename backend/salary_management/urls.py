from django.urls import path

from . import views

app_name = 'salary_management'

urlpatterns = [
    path('admin/', views.AdminDashboard.as_view(), name='admin_dashboard'),
    path('employee/',
         views.EmployeeDashboard.as_view(), name='employee_dashboard'),

    # path('', views.SalaryListView.as_view(), name='salary_list'),
    path('salary/<int:id>/', views.salary_update_view, name='salary_update_view'),
    path('transactions/', views.SalaryTransactionListView.as_view(),
         name='transaction_list_view'),
    path('transactions/add/', views.SalaryTransactionCreateView.as_view(),
         name='transaction_create_view'),
    path('transactions/update/<int:pk>/', views.SalaryTransactionUpdateView.as_view(),
         name='salary_transaction_update_view'),
    path('transactions/delete/<int:pk>/', views.SalaryTransactionDeleteView.as_view(),
         name='salary_transaction_delete_view'),
]
