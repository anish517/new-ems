from django.urls import path, include

from . import views

app_name = 'authentication'

urlpatterns = [
    path('signup/', views.SignUpView.as_view(), name='signup'),
    path('signin/', views.signin_view, name='signin'),
    path('signout/', views.signout_view, name='signout'),
    path('dashboard/', views.Dashboard.as_view(), name='dashboard'),
]
