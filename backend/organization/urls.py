from django.urls import path
from . import views

app_name = 'organization'

urlpatterns = [
    path('', views.OrganizationDetailView.as_view(), name='detail'),
    path('create/', views.OrganizationCreateView.as_view(), name='create'),
    path('list/', views.OrganizationListView.as_view(), name='list'),
    path('update/<int:pk>/', views.OrganizationUpdateView.as_view(), name='update'),

    path('department/', views.DepartmentListView.as_view(), name='department_list'),
    path('department/create/', views.DepartmentCreateView.as_view(),
         name='create_department'),
    path('department/<int:pk>/', views.DepartmentDetailView.as_view(),
         name='department_detail'),
    path('department/delete/<int:pk>/',
         views.DepartmentDeleteView.as_view(), name='delete_department'),

    path('designations/', views.PostListView.as_view(), name='post_list'),
    path('designations/add/', views.PostCreateView.as_view(), name='create_post'),
    path('designations/delete/<int:pk>/',
         views.PostDeleteView.as_view(), name='delete_post'),
    path('employees/', views.EmployeeListView.as_view(), name='employee_list'),
    path('employees/add/', views.EmployeeCreateView.as_view(), name='add_employee'),
    path('employees/<int:pk>/', views.EmployeeDetailView.as_view(),
         name='employee_detail'),
    path('employees/update/<int:pk>/',
         views.EmployeeUpdateView.as_view(), name='employee_update'),
    path('employees/delete/<int:pk>/',
         views.employee_delete_view, name='employee_delete'),
    path('employees/undo-delete/<int:pk>/',
         views.employee_undo_delete, name='employee_undo_delete'),
    path('employees/<int:pk>/analysis-report/',
         views.AnalysisReportList.as_view(), name='employee_analysis_report'),
    path('analysis-report/feedback/create', views.create_analyis_report_feedback,
         name='create_analysis_report_feedback'),
    path('analysis-report/feedback/delete/<int:pk>/',
         views.delete_analysis_report_feedback, name='delete_analysis_report_feedback'),
    path('policies/', views.organization_policies_list_view, name='policies_list'),

    path('organization-folder/',
         views.OrganizationFolderListView.as_view(), name='folder_list'),
    path('organization-folder/create/',
         views.OrganizationFolderCreateView.as_view(), name='folder_create'),
    path('organization-folder/<int:pk>/',
         views.OrganizationFolderDetailView.as_view(), name='folder_detail'),
    path('organization-folder/<int:pk>/add-file/',
         views.OrganizationFileCreateView.as_view(), name='organization_file_create'),
    path('organization-folder/delete-file/<int:pk>/',
         views.OrganizationFileDeleteView.as_view(), name='organization_file_delete'),
]
