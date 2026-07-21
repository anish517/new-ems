from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import EventViewSet, CategoryViewSet, DateViewSet

router = DefaultRouter()
router.register(r'events', EventViewSet, basename='events')
router.register(r'categories', CategoryViewSet)
router.register(r'dates', DateViewSet, basename='date')


urlpatterns = [
    path('', include(router.urls)),
]
