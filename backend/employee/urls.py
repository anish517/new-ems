from django.urls import path
from . import views

app_name = 'employee'

urlpatterns = [
    path('contracts/', views.ContractListView.as_view(), name='contract_list'),
    path('contracts/add/', views.ContractCreateView.as_view(),
         name='contract_create'),
    path('contracts/<int:pk>/', views.ContractDetailView.as_view(),
         name='contract_detail'),
    path('contracts/<int:pk>/edit/',
         views.ContractUpdateView.as_view(), name='contract_update'),

    path('dashboard/', views.EmployeeDashboard.as_view(), name='dashboard'),
]
