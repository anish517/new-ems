import time
import nepali_datetime
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .serializers import NoticeSerializer, CompanyPolicySerializer
from noticeboard.models import Notice, CompanyPolicy


class NoticeboardListView(generics.ListCreateAPIView):
    serializer_class = NoticeSerializer
    permission_classes = [IsAuthenticated]

    def _get_employee(self):
        try:
            return self.request.user.employee
        except Exception:
            return None

    def _get_org(self):
        user = self.request.user
        org = getattr(user.employee, 'organization', None) if hasattr(user, 'employee') else None
        if not org:
            if user.organization.exists():
                org = user.organization.first()
            elif getattr(user, 'is_superuser', False) or getattr(user, 'is_hr', False):
                from organization.models import Organization
                org = Organization.objects.first()
        return org

    def get_queryset(self):
        from django.db.models import Q
        user = self.request.user
        org = self._get_org()
        
        if not org:
            if user.is_superuser:
                return Notice.objects.all().order_by('-id')
            return Notice.objects.none()
            
        return Notice.objects.filter(
            Q(organization=org) | Q(organization__isnull=True)
        ).order_by('-id')

    def perform_create(self, serializer):
        user = self.request.user
        employee = self._get_employee()
        
        # Use provided date if available, else today
        today = nepali_datetime.date.today()
        provided_date_str = self.request.data.get('date')
        if provided_date_str:
            try:
                y, m, d = map(int, provided_date_str.split('-'))
                date_val = nepali_datetime.date(y, m, d)
            except Exception:
                date_val = today
        else:
            date_val = today

        org = self._get_org()
        if employee:
            serializer.save(
                organization=org,
                created_by=employee,
                date=date_val,
                created_at=today,
            )
        else:
            serializer.save(
                organization=org,
                date=date_val,
                created_at=today,
            )

class NoticeDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = NoticeSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        from django.db.models import Q
        user = self.request.user
        try:
            employee = user.employee
            return Notice.objects.filter(Q(organization=employee.organization) | Q(organization__isnull=True))
        except Exception:
            orgs = user.organization.all()
            if orgs.exists():
                return Notice.objects.filter(Q(organization__in=orgs) | Q(organization__isnull=True))
            if user.is_superuser:
                return Notice.objects.all()
            return Notice.objects.none()


# ─── Company Policy ─────────────────────────────────────────────────

class CompanyPolicyListCreateView(generics.ListCreateAPIView):
    """GET: all active policies for the org. POST: admin only."""
    serializer_class = CompanyPolicySerializer
    permission_classes = [IsAuthenticated]

    def _get_org(self):
        user = self.request.user
        try:
            return user.employee.organization
        except Exception:
            orgs = user.organization.all()
            return orgs.first() if orgs.exists() else None

    def get_queryset(self):
        org = self._get_org()
        if not org:
            return CompanyPolicy.objects.none()
        qs = CompanyPolicy.objects.filter(organization=org, is_active=True)
        category = self.request.query_params.get('category')
        if category:
            qs = qs.filter(category__iexact=category)
        return qs

    def perform_create(self, serializer):
        from rest_framework.exceptions import PermissionDenied
        user = self.request.user
        is_admin = user.organization.exists() or user.is_superuser
        if not is_admin:
            raise PermissionDenied('Only admins can create policies.')
        org = self._get_org()
        serializer.save(organization=org, created_by=user)


class CompanyPolicyDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Admin: full CRUD. Employee: read-only GET."""
    serializer_class = CompanyPolicySerializer
    permission_classes = [IsAuthenticated]
    queryset = CompanyPolicy.objects.all()
    http_method_names = ['get', 'patch', 'delete']

    def update(self, request, *args, **kwargs):
        if not (request.user.organization.exists() or request.user.is_superuser):
            return Response({'error': 'Only admins can edit policies.'}, status=status.HTTP_403_FORBIDDEN)
        return super().update(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        if not (request.user.organization.exists() or request.user.is_superuser):
            return Response({'error': 'Only admins can delete policies.'}, status=status.HTTP_403_FORBIDDEN)
        return super().destroy(request, *args, **kwargs)

