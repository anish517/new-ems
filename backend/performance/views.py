from django.utils import timezone
from rest_framework import generics, status, viewsets
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from notification.models import Notification
from organization.models import Employee, OrganizationSettings, Organization
from performance.models import (
    PerformanceReview,
    PerformanceCategory,
    PerformanceReviewerAccess,
)
from performance.serializers import (
    PerformanceReviewSerializer,
    PerformanceCategorySerializer,
    PerformanceReviewerAccessSerializer,
    PerformanceReviewerCreateSerializer,
    ReviewableEmployeeSerializer,
)


def _is_performance_admin(user):
    return bool(
        user.is_superuser
        or user.organization.exists()
        or getattr(user, 'is_hr', False)
    )


def _get_active_reviewer_access(user):
    if not getattr(user, 'is_performance_reviewer', False):
        return None
    try:
        access = user.performance_access
        return access if access and access.is_active else None
    except Exception:
        return None


def _resolve_org(user):
    org = user.organization.first()
    if org:
        return org
    access = _get_active_reviewer_access(user)
    if access and access.organization:
        return access.organization
    if hasattr(user, 'employee') and user.employee.organization:
        return user.employee.organization
    if user.is_superuser or getattr(user, 'is_hr', False):
        return Organization.objects.first()
    return None


def _validate_review_permission(user, employee, category):
    """
    Enforces role, category, tenant, and self-review rules when creating or
    updating a PerformanceReview.
    """
    if employee is None:
        raise ValidationError({'employee': 'Employee is required.'})

    access = _get_active_reviewer_access(user)

    # Always block self-review — both single-account (same user_id)
    # and two-account (reviewer's linked_employee == target employee)
    if employee.user_id == user.id:
        raise PermissionDenied('You cannot give a performance review to yourself.')
    if access and access.linked_employee_id and access.linked_employee_id == employee.id:
        raise PermissionDenied('You cannot give a performance review to yourself.')

    if _is_performance_admin(user):
        org = _resolve_org(user)
        emp_org = employee.organization
        if org and emp_org and emp_org.id != org.id:
            raise PermissionDenied('You can only review employees in your organization.')
        return

    if access is not None:
        emp_org = employee.organization
        if not emp_org or emp_org.id != access.organization_id:
            raise PermissionDenied('You can only review employees in your organization.')
        if category is None:
            raise ValidationError({'category': 'A performance category is required.'})
        if not access.categories.filter(pk=category.pk).exists():
            raise PermissionDenied('You are not assigned to review this performance category.')
        return

    raise PermissionDenied('Only administrators or assigned performance reviewers can submit reviews.')


def check_performance_enabled(user):
    """Verifies that Daily Performance is enabled in OrganizationSettings for employees.
    Admins, Superusers, HR users, and active Performance Reviewers always retain access."""
    if _is_performance_admin(user) or _get_active_reviewer_access(user) is not None:
        return

    try:
        org = None
        if hasattr(user, 'employee') and user.employee.organization:
            org = user.employee.organization

        if org:
            settings_obj = OrganizationSettings.objects.filter(organization=org).first()
            if settings_obj and not settings_obj.enable_daily_performance:
                raise PermissionDenied("Daily Performance feature is currently disabled by your administrator.")
    except PermissionDenied:
        raise
    except Exception:
        pass


class PerformanceCategoryViewSet(viewsets.ModelViewSet):
    serializer_class = PerformanceCategorySerializer
    permission_classes = [IsAuthenticated]

    def _is_admin(self, user):
        return _is_performance_admin(user)

    def get_queryset(self):
        user = self.request.user
        check_performance_enabled(user)

        # Performance Reviewer: only their assigned categories
        if not self._is_admin(user):
            access = _get_active_reviewer_access(user)
            if access is not None:
                return access.categories.all().order_by('name')

        try:
            org = _resolve_org(user)
            if org:
                return PerformanceCategory.objects.filter(organization=org)
            return PerformanceCategory.objects.none() if not self._is_admin(user) else PerformanceCategory.objects.all()
        except Exception:
            return PerformanceCategory.objects.none()

    def perform_create(self, serializer):
        user = self.request.user
        if not self._is_admin(user):
            raise PermissionDenied("Only administrators can create performance categories.")

        org = _resolve_org(user)
        if org:
            serializer.save(organization=org)
        else:
            serializer.save()

    def perform_update(self, serializer):
        if not self._is_admin(self.request.user):
            raise PermissionDenied("Only administrators can edit performance categories.")
        serializer.save()

    def perform_destroy(self, instance):
        if not self._is_admin(self.request.user):
            raise PermissionDenied("Only administrators can delete performance categories.")
        instance.delete()


class PerformanceReviewListCreateView(generics.ListCreateAPIView):
    serializer_class = PerformanceReviewSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        check_performance_enabled(user)
        employee_id = self.request.GET.get('employee')
        category_id = self.request.GET.get('category')
        reviewer_id = self.request.GET.get('reviewer')
        mine = self.request.GET.get('mine')

        # Admin: see all reviews in org (with optional filters)
        if _is_performance_admin(user):
            org = _resolve_org(user)
            qs = (
                PerformanceReview.objects.filter(employee__post__department__organization=org)
                if org else PerformanceReview.objects.all()
            )
            if employee_id:
                qs = qs.filter(employee_id=employee_id)
            if category_id:
                qs = qs.filter(category_id=category_id)
            if reviewer_id:
                qs = qs.filter(reviewer_id=reviewer_id)
            return qs

        # Performance Reviewer: only reviews in their assigned categories within their org
        access = _get_active_reviewer_access(user)
        if access is not None:
            qs = PerformanceReview.objects.filter(
                employee__post__department__organization=access.organization,
                category__in=access.categories.all(),
            )
            if employee_id:
                qs = qs.filter(employee_id=employee_id)
            if category_id:
                qs = qs.filter(category_id=category_id)
            if mine and mine.lower() in ('true', '1'):
                qs = qs.filter(reviewer=user)
            return qs

        # Employee: only their own reviews
        try:
            return PerformanceReview.objects.filter(employee=user.employee)
        except Exception:
            return PerformanceReview.objects.none()

    def perform_create(self, serializer):
        user = self.request.user
        check_performance_enabled(user)
        employee = serializer.validated_data.get('employee')
        category = serializer.validated_data.get('category')
        _validate_review_permission(user, employee, category)

        review = serializer.save(reviewer=user)


class PerformanceReviewRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = PerformanceReviewSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        check_performance_enabled(user)

        if _is_performance_admin(user):
            org = _resolve_org(user)
            return (
                PerformanceReview.objects.filter(employee__post__department__organization=org)
                if org else PerformanceReview.objects.all()
            )

        access = _get_active_reviewer_access(user)
        if access is not None:
            return PerformanceReview.objects.filter(
                employee__post__department__organization=access.organization,
                category__in=access.categories.all(),
            )

        # Employees can only retrieve their own reviews (update/delete blocked below)
        try:
            return PerformanceReview.objects.filter(employee=user.employee)
        except Exception:
            return PerformanceReview.objects.none()

    def perform_update(self, serializer):
        user = self.request.user
        instance = serializer.instance

        if not _is_performance_admin(user):
            access = _get_active_reviewer_access(user)
            if access is None:
                raise PermissionDenied('You do not have permission to edit performance reviews.')
            if instance.reviewer_id != user.id:
                raise PermissionDenied('You can only edit performance reviews you created.')

        employee = serializer.validated_data.get('employee', instance.employee)
        category = serializer.validated_data.get('category', instance.category)
        _validate_review_permission(user, employee, category)
        serializer.save()

    def perform_destroy(self, instance):
        user = self.request.user
        if not _is_performance_admin(user):
            access = _get_active_reviewer_access(user)
            if access is None:
                raise PermissionDenied('You do not have permission to delete performance reviews.')
            if instance.reviewer_id != user.id:
                raise PermissionDenied('You can only delete performance reviews you created.')
        instance.delete()


class PerformanceReviewReplyView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        check_performance_enabled(request.user)
        try:
            review = PerformanceReview.objects.get(pk=pk)
        except PerformanceReview.DoesNotExist:
            return Response({'error': 'Review not found'}, status=status.HTTP_404_NOT_FOUND)

        # Only the reviewed employee can reply to their review
        if not (review.employee and review.employee.user_id == request.user.id):
            raise PermissionDenied('You can only reply to your own performance reviews.')

        reply = request.data.get('reply', '').strip()
        if not reply:
            return Response({'error': 'Reply cannot be empty'}, status=status.HTTP_400_BAD_REQUEST)

        review.reply = reply
        review.replied_at = timezone.now()
        review.save()

        # Notify reviewer (Admin or Performance Reviewer)
        if review.reviewer:
            emp_name = review.employee.user.full_name if review.employee and review.employee.user else 'Employee'
            Notification.objects.create(
                user=review.reviewer,
                title='Performance Review Reply',
                message=f'{emp_name} replied to your review.',
                is_read=False,
            )

        return Response(PerformanceReviewSerializer(review, context={'request': request}).data)


class PerformanceReviewerViewSet(viewsets.ModelViewSet):
    """
    Admin-only management of separate Performance Reviewer login accounts
    and their assigned PerformanceCategory permissions.
    """
    permission_classes = [IsAuthenticated]
    serializer_class = PerformanceReviewerAccessSerializer

    def _require_admin(self, user):
        if not _is_performance_admin(user):
            raise PermissionDenied('Only administrators can manage performance reviewers.')

    def get_queryset(self):
        self._require_admin(self.request.user)
        org = _resolve_org(self.request.user)
        qs = PerformanceReviewerAccess.objects.select_related(
            'reviewer', 'linked_employee__user', 'organization'
        ).prefetch_related('categories')
        if org:
            return qs.filter(organization=org)
        return qs

    def get_serializer_class(self):
        if self.action == 'create':
            return PerformanceReviewerCreateSerializer
        return PerformanceReviewerAccessSerializer

    def create(self, request, *args, **kwargs):
        self._require_admin(request.user)
        org = _resolve_org(request.user)
        if not org:
            return Response({'error': 'No organization found for this administrator.'}, status=status.HTTP_400_BAD_REQUEST)

        serializer = PerformanceReviewerCreateSerializer(
            data=request.data, context={'request': request, 'organization': org}
        )
        serializer.is_valid(raise_exception=True)
        access = serializer.save()
        out = PerformanceReviewerAccessSerializer(access, context={'request': request})
        return Response(out.data, status=status.HTTP_201_CREATED)

    def perform_update(self, serializer):
        self._require_admin(self.request.user)
        serializer.save()

    def perform_destroy(self, instance):
        """
        Revoke reviewer access and deactivate standalone reviewer login
        while keeping historical PerformanceReview rows intact.
        """
        self._require_admin(self.request.user)
        reviewer = instance.reviewer
        instance.delete()
        reviewer.is_performance_reviewer = False
        update_fields = ['is_performance_reviewer']
        if not hasattr(reviewer, 'employee') and not reviewer.is_superuser:
            reviewer.is_active = False
            update_fields.append('is_active')
        reviewer.save(update_fields=update_fields)


class MyReviewCategoriesView(APIView):
    """
    Returns the PerformanceCategory items the current user is allowed to score.
    - Performance Reviewer: only their assigned categories.
    - Admin / HR / Superuser: all categories in their organization.
    - Regular Employee: 403 Forbidden.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        if _is_performance_admin(user):
            org = _resolve_org(user)
            qs = PerformanceCategory.objects.filter(organization=org) if org else PerformanceCategory.objects.all()
            return Response(PerformanceCategorySerializer(qs, many=True).data)

        access = _get_active_reviewer_access(user)
        if access is not None:
            qs = access.categories.all().order_by('name')
            return Response(PerformanceCategorySerializer(qs, many=True).data)

        raise PermissionDenied('Only administrators or assigned performance reviewers can access review categories.')


class ReviewableEmployeesView(APIView):
    """
    Returns active organization employees that the current Admin or Performance
    Reviewer is allowed to score (automatically excluding self and linked_employee).
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        is_admin = _is_performance_admin(user)
        access = _get_active_reviewer_access(user)

        if not is_admin and access is None:
            raise PermissionDenied('Only administrators or assigned performance reviewers can view reviewable employees.')

        org = access.organization if (not is_admin and access is not None) else _resolve_org(user)
        qs = Employee.objects.filter(is_active=True).select_related('user', 'post__department')
        if org:
            qs = qs.filter(post__department__organization=org)

        # Exclude self (same account) and linked_employee (two-account setup)
        qs = qs.exclude(user_id=user.id)
        if access and access.linked_employee_id:
            qs = qs.exclude(id=access.linked_employee_id)

        qs = qs.order_by('user__first_name', 'user__last_name')
        return Response(ReviewableEmployeeSerializer(qs, many=True).data)
