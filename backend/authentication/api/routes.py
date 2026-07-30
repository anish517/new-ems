from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import AccountViewSet, ChangePasswordView, MeView, ForgotPasswordView, PasswordResetConfirmView

router = DefaultRouter()
router.register(r'accounts', AccountViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('me/', MeView.as_view(), name='me'),
    path('change-password/', ChangePasswordView.as_view(), name='change_password'),
    path('forgot-password/', ForgotPasswordView.as_view(), name='forgot_password'),
    path('reset-password/', PasswordResetConfirmView.as_view(), name='reset_password_confirm'),
]
