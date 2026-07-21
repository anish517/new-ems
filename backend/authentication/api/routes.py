from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import AccountViewSet, ChangePasswordView, MeView

router = DefaultRouter()
router.register(r'accounts', AccountViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('me/', MeView.as_view(), name='me'),
    path('change-password/', ChangePasswordView.as_view(), name='change_password'),
]
