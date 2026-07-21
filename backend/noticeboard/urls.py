from django.urls import path
from . import views

app_name = 'noticeboard'

urlpatterns = [
    path('', views.Dashboard.as_view(), name='dashboard'),
    path('list/', views.NoticeListView.as_view(), name='notice_list'),
    path('add/', views.CreateNoticeView.as_view(), name='notice_create'),
    path('update/<int:pk>/', views.NoticeUpdateView.as_view(), name='notice_update'),
    path('delete/<int:pk>/', views.NoticeDeleteView.as_view(), name='notice_delete'),
]
