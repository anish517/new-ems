from django.urls import path, include
from rest_framework.routers import DefaultRouter
from performance.views import (
    PerformanceReviewListCreateView,
    PerformanceReviewReplyView,
    PerformanceReviewRetrieveUpdateDestroyView,
    PerformanceCategoryViewSet,
    PerformanceReviewerViewSet,
    MyReviewCategoriesView,
    ReviewableEmployeesView,
)

router = DefaultRouter()
router.register(r'categories', PerformanceCategoryViewSet, basename='performance-categories')
router.register(r'reviewers', PerformanceReviewerViewSet, basename='performance-reviewers')

urlpatterns = [
    path('', include(router.urls)),
    path('my-categories/', MyReviewCategoriesView.as_view(), name='my-review-categories'),
    path('reviewable-employees/', ReviewableEmployeesView.as_view(), name='reviewable-employees'),
    path('reviews/', PerformanceReviewListCreateView.as_view(), name='review-list-create'),
    path('reviews/<int:pk>/', PerformanceReviewRetrieveUpdateDestroyView.as_view(), name='review-detail'),
    path('reviews/<int:pk>/reply/', PerformanceReviewReplyView.as_view(), name='review-reply'),
]
