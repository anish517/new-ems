from django.urls import path

from . import views

urlpatterns = [
    path('contract/<int:pk>/', views.ContractRetrieveUpdateDestroyAPIView.as_view()),
]
