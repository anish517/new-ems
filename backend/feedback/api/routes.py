from django.urls import path
from . import views

urlpatterns = [
    path('categories/', views.ComplainCategoryListView.as_view()),
    path('', views.ComplainListCreateView.as_view()),
    path('<int:pk>/', views.ComplainDetailView.as_view()),
    path('<int:pk>/reply/', views.ComplainReplyCreateView.as_view()),
]
