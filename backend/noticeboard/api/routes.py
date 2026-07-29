from django.urls import path
from . import views


urlpatterns = [
    path('notices/', views.NoticeboardListView.as_view()),
    path('notices/<int:pk>/', views.NoticeDetailView.as_view()),
    # Company Policies
    path('policies/', views.CompanyPolicyListCreateView.as_view(), name='policy-list'),
    path('policies/<int:pk>/', views.CompanyPolicyDetailView.as_view(), name='policy-detail'),
]
