from django.urls import path
from performance.views import PerformanceReviewListCreateView, PerformanceReviewReplyView

urlpatterns = [
    path('reviews/', PerformanceReviewListCreateView.as_view(), name='review-list-create'),
    path('reviews/<int:pk>/reply/', PerformanceReviewReplyView.as_view(), name='review-reply'),
]
