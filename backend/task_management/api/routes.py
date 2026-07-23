from django.urls import path
from task_management.api.views import (
    EmployeeTaskSummaryAPIView, OrganizationProjectSummary,
    OrganizationTaskSummaryAPIView, ProjectListAPIView, ProjectTaskSummaryAPIView, TaskListCreateAPIView, TaskRetrieveUpdateDestroyView)

urlpatterns = [
    path('tasks/', TaskListCreateAPIView.as_view()),
    path('tasks/<int:pk>/', TaskRetrieveUpdateDestroyView.as_view()),
    path('tasks/employee-summary/<int:employee_id>/',
         EmployeeTaskSummaryAPIView.as_view()),
    path('tasks/organization-summary/<int:organization_id>/',
         OrganizationTaskSummaryAPIView.as_view()),
    path('tasks/project-summary/<int:project_id>/',
         ProjectTaskSummaryAPIView.as_view()),
    path('projects/organization-summary/<int:organization_id>/',
         OrganizationProjectSummary.as_view()),
    path('projects/', ProjectListAPIView.as_view()),
]
