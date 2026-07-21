from django.urls import path
from . import views

app_name = 'feedback'

urlpatterns = [
    path('admin/', views.AdminDashboard.as_view(), name='admin_dashboard'),
    path('employee/', views.EmployeeDashboard.as_view(), name='employee_dashboard'),
    path('complains/', views.complain_list_view, name='complain_list'),
    path('complains/add/', views.ComplainCreateView.as_view(), name='complain_add'),
    path('complains/<int:pk>/', views.ComplainDetailView.as_view(),
         name='complain_detail'),
    path('complains/edit/<int:pk>/',
         views.ComplainUpdateView.as_view(), name='complain_update'),
    path('complain/delete/<int:pk>/',
         views.complain_delete_view, name='complain_delete'),
    path('complain/reply/add/', views.create_complain_reply,
         name='complain_reply_add'),

]
