from django.urls import path
from . import views

app_name = 'calendar_app'

urlpatterns = [
    path('', views.Calendar.as_view(), name='calendar'),
    path('add-event/', views.EventAddView.as_view(), name='event-add'),
    path('edit-event/<int:pk>/',
         views.EventUpdateView.as_view(), name='event_update'),
]
