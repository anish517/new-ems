from django.urls import path
from task_management.api.views import (
    EmployeeTaskSummaryAPIView,
    OrganizationProjectSummary,
    OrganizationTaskSummaryAPIView,
    ProjectFileUploadAPIView,
    ProjectListAPIView,
    ProjectListCreateAPIView,
    ProjectRetrieveUpdateDestroyAPIView,
    ProjectTaskSummaryAPIView,
    TaskListCreateAPIView,
    TaskProgressReportDestroyAPIView,
    TaskProgressReportListCreateAPIView,
    TaskRetrieveUpdateDestroyView,
)

urlpatterns = [
    # Projects
    path("projects/", ProjectListCreateAPIView.as_view()),
    path("projects/<int:pk>/", ProjectRetrieveUpdateDestroyAPIView.as_view()),
    path("projects/<int:pk>/files/", ProjectFileUploadAPIView.as_view()),
    path("projects/list/", ProjectListAPIView.as_view()),
    path("projects/organization-summary/<int:organization_id>/", OrganizationProjectSummary.as_view()),

    # Tasks
    path("tasks/", TaskListCreateAPIView.as_view()),
    path("tasks/<int:pk>/", TaskRetrieveUpdateDestroyView.as_view()),
    path("tasks/employee-summary/<int:employee_id>/", EmployeeTaskSummaryAPIView.as_view()),
    path("tasks/organization-summary/<int:organization_id>/", OrganizationTaskSummaryAPIView.as_view()),
    path("tasks/project-summary/<int:project_id>/", ProjectTaskSummaryAPIView.as_view()),

    # Task Progress Reports
    path("tasks/<int:task_id>/progress/", TaskProgressReportListCreateAPIView.as_view()),
    path("progress/<int:pk>/", TaskProgressReportDestroyAPIView.as_view()),
]
