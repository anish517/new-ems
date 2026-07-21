from django.urls import path
from . import views

urlpatterns = [
    path('', views.FiscalYearListView.as_view()),
    path('<int:pk>/', views.FiscalYearDetailView.as_view()),
]