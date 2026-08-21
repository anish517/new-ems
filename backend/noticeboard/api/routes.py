from django.urls import path
from . import views


urlpatterns = [
    path('notices/', views.NoticeboardListView.as_view()),
    path('notices/<int:pk>/', views.NoticeDetailView.as_view()),
    # Company Policies
    path('policies/approve/', views.PolicyApproveView.as_view(), name='policy-approve'),
    path('policies/approval-status/', views.PolicyApprovalStatusView.as_view(), name='policy-approval-status'),
    path('policies/approvals/', views.PolicyApprovalAuditListView.as_view(), name='policy-approvals-audit'),
    path('policies/', views.CompanyPolicyListCreateView.as_view(), name='policy-list'),
    path('policies/<int:pk>/', views.CompanyPolicyDetailView.as_view(), name='policy-detail'),
]

