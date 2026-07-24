from django.utils import timezone
from rest_framework import generics, status, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated

from notification.models import Notification
from organization.models import Employee
from performance.models import PerformanceReview, PerformanceCategory
from performance.serializers import PerformanceReviewSerializer, PerformanceCategorySerializer


class PerformanceCategoryViewSet(viewsets.ModelViewSet):
    serializer_class = PerformanceCategorySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        try:
            org = user.organization.first()
            if not org and hasattr(user, 'employee'):
                org = user.employee.organization
            if org:
                return PerformanceCategory.objects.filter(organization=org)
            return PerformanceCategory.objects.none()
        except Exception:
            return PerformanceCategory.objects.none()

    def perform_create(self, serializer):
        user = self.request.user
        org = user.organization.first()
        if org:
            serializer.save(organization=org)


class PerformanceReviewListCreateView(generics.ListCreateAPIView):
    serializer_class = PerformanceReviewSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        employee_id = self.request.GET.get('employee')

        # Admin: see all reviews (optionally filtered by employee)
        is_admin = user.organization.exists() or user.is_superuser or getattr(user, 'is_hr', False)
        if is_admin:
            if employee_id:
                return PerformanceReview.objects.filter(employee_id=employee_id)
            # Get org employees
            try:
                org = user.organization.first()
                if not org and hasattr(user, 'employee'):
                    org = user.employee.organization
                if org:
                    return PerformanceReview.objects.filter(employee__organization=org)
                return PerformanceReview.objects.all()
            except Exception:
                return PerformanceReview.objects.all()

        # Employee: only their own reviews
        try:
            return PerformanceReview.objects.filter(employee=user.employee)
        except Exception:
            return PerformanceReview.objects.none()

    def perform_create(self, serializer):
        review = serializer.save(reviewer=self.request.user)
        # Notify the employee
        if review.employee and review.employee.user:
            Notification.objects.create(
                user=review.employee.user,
                title='New Performance Review',
                message=f'You received a performance score of {review.score}/10. Tap to view.',
                is_read=False,
            )


class PerformanceReviewRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = PerformanceReviewSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        is_admin = user.organization.exists() or user.is_superuser or getattr(user, 'is_hr', False)
        if is_admin:
            try:
                org = user.organization.first()
                if not org and hasattr(user, 'employee'):
                    org = user.employee.organization
                if org:
                    return PerformanceReview.objects.filter(employee__organization=org)
                return PerformanceReview.objects.all()
            except Exception:
                return PerformanceReview.objects.all()
        # Employees should not be able to update/destroy, but maybe retrieve. 
        try:
            return PerformanceReview.objects.filter(employee=user.employee)
        except Exception:
            return PerformanceReview.objects.none()


class PerformanceReviewReplyView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        try:
            review = PerformanceReview.objects.get(pk=pk)
        except PerformanceReview.DoesNotExist:
            return Response({'error': 'Review not found'}, status=status.HTTP_404_NOT_FOUND)

        reply = request.data.get('reply', '').strip()
        if not reply:
            return Response({'error': 'Reply cannot be empty'}, status=status.HTTP_400_BAD_REQUEST)

        review.reply = reply
        review.replied_at = timezone.now()
        review.save()

        # Notify reviewer (admin)
        if review.reviewer:
            emp_name = review.employee.user.full_name if review.employee and review.employee.user else 'Employee'
            Notification.objects.create(
                user=review.reviewer,
                title='Performance Review Reply',
                message=f'{emp_name} replied to your review.',
                is_read=False,
            )

        return Response(PerformanceReviewSerializer(review).data)
