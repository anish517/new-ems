from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'employees', views.EmployeeViewSet, basename='employee')
router.register(r'national-ids', views.NationalIdViewSet)
router.register(r'qualifications', views.QualificationViewSet)
router.register(r'bank-details', views.BankDetailViewSet)
router.register(r'documents', views.DocumentViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('organization_file/<int:pk>/',
         views.OrganizationFileRetrieveAPIView.as_view()),
    path('addresses/', views.EmployeeAddressCreateView.as_view()),
    path('addresses/<int:pk>/', views.EmployeeAddressDetailView.as_view()),
    path('analysis-report/', views.EmployeeAnalysisReportListAPIView.as_view()),
    path('department/<int:pk>/',
         views.DepartmentRetrieveUpdateDeleteAPIView.as_view()),
    path('address/set/', views.SetOrganizationAddressView.as_view()),
    path('employees/<int:employee_id>/report/', views.EmployeeReportAPIView.as_view()),
    path('settings/', views.OrganizationSettingsView.as_view(), name='organization-settings'),
    # Employee profile self-edit requests
    path('profile-change-requests/', views.ProfileChangeRequestListCreateAPIView.as_view(), name='profile-change-requests'),
    path('profile-change-requests/<int:pk>/action/', views.AdminProfileChangeRequestActionAPIView.as_view(), name='profile-change-action'),
]
