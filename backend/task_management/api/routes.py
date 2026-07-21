from django.urls import path

from . import views

urlpatterns = [
    path('tasks/', views.TaskListCreateAPIView.as_view()),
    path('task/<int:pk>/', views.TaskRetrieveUpdateView.as_view()),
    path('employee-summary/<int:employee_id>/',
         views.EmployeeTaskSummaryAPIView.as_view()),
    path('organization-summary/<int:organization_id>/',
         views.OrganizationTaskSummaryAPIView.as_view()),
    path('project-summary/<int:project_id>/',
         views.ProjectTaskSummaryAPIView.as_view()),
    path('project-summary/organization/<int:organization_id>/',
         views.OrganizationProjectSummary.as_view()),
    path('projects/', views.ProjectListAPIView.as_view())
]
