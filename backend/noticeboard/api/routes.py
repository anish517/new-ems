from django.urls import path
from . import views


urlpatterns = [
    path('notices/', views.NoticeboardListView.as_view()),
    path('notices/<int:pk>/', views.NoticeDetailView.as_view()),

]
