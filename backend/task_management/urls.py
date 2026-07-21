from django.urls import path

from . import views

app_name = 'task_management'

urlpatterns = [
    path('admin/', views.AdminDashboard.as_view(), name='admin_dashboard'),
    path('employee/', views.EmployeeDashboard.as_view(), name='employee_dashboard'),
    path('project/create/', views.ProjectCreateView.as_view(), name='project_create'),
    path('project/<int:pk>/', views.ProjectDetailView.as_view(),
         name='project_detail'),
    path('tasks/', views.task_list, name='task_list'),
    path('tasks/create/', views.TaskCreate.as_view(), name='task_create'),
    path('tasks/<int:pk>/', views.TaskDetail.as_view(), name='task_details'),
    path('tasks/<int:pk>/edit/', views.TaskUpdate.as_view(), name='task-update'),
]
