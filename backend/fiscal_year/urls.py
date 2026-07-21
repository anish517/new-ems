from django.urls import path
from fiscal_year.api import routes
from . import views

app_name = 'fiscal_year'

urlpatterns = [
    path('', views.FiscalYearListView.as_view(), name='list'),
    path('add/', views.FiscalYearCreateView.as_view(), name='create'),
]

urlpatterns += routes.urlpatterns