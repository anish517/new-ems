from django.urls import path, include
from rest_framework.routers import DefaultRouter
from performance.views import (
    PerformanceReviewListCreateView, 
    PerformanceReviewReplyView,
    PerformanceReviewRetrieveUpdateDestroyView,
    PerformanceCategoryViewSet
)

router = DefaultRouter()
router.register(r'categories', PerformanceCategoryViewSet, basename='performance-categories')

urlpatterns = [
    path('', include(router.urls)),
    path('reviews/', PerformanceReviewListCreateView.as_view(), name='review-list-create'),
    path('reviews/<int:pk>/', PerformanceReviewRetrieveUpdateDestroyView.as_view(), name='review-detail'),
    path('reviews/<int:pk>/reply/', PerformanceReviewReplyView.as_view(), name='review-reply'),
]
