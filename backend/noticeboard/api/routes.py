from django.urls import path
from . import views


urlpatterns = [
    path('notices/', views.NoticeboardListView.as_view()),

]
