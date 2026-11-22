import nepali_datetime
from rest_framework import generics
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated

from fiscal_year.models import FiscalYear
from organization.models import Organization
from .serializers import FiscalYearSerializer


def _get_active_finance_access(user):
    if not getattr(user, 'is_finance', False):
        return None
    try:
        access = user.finance_access
        return access if access and access.is_active else None
    except Exception:
        return None


def _can_manage_fiscal_years(user):
    return bool(
        user.is_superuser
        or user.organization.exists()
        or getattr(user, 'is_hr', False)
        or _get_active_finance_access(user) is not None
    )


def _get_org(user):
    try:
        return user.employee.post.department.organization
    except Exception:
        pass
    if user.organization.exists():
        return user.organization.first()
    finance_access = _get_active_finance_access(user)
    if finance_access and finance_access.organization:
        return finance_access.organization
    if user.is_superuser or getattr(user, 'is_hr', False):
        return Organization.objects.first()
    return None


def _ensure_default_fiscal_years(org):
    if not org:
        return
    current_year = nepali_datetime.date.today().year
    # Generate a range around current year (e.g. 2080/81 to 2085/86)
    for y in range(current_year - 2, current_year + 3):
        title = f"{y}/{str(y + 1)[-2:]}"
        FiscalYear.objects.get_or_create(organization=org, title=title)


class FiscalYearListView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = FiscalYearSerializer

    def get_queryset(self):
        org = _get_org(self.request.user)
        if not org:
            return FiscalYear.objects.none()
        if not FiscalYear.objects.filter(organization=org).exists():
            _ensure_default_fiscal_years(org)
        return FiscalYear.objects.filter(organization=org).order_by('-id')

    def perform_create(self, serializer):
        if not _can_manage_fiscal_years(self.request.user):
            raise PermissionDenied('Only administrators or finance users can create fiscal years.')
        org = _get_org(self.request.user)
        serializer.save(organization=org)


class FiscalYearDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = FiscalYearSerializer

    def get_queryset(self):
        org = _get_org(self.request.user)
        return FiscalYear.objects.filter(organization=org) if org else FiscalYear.objects.none()

    def perform_update(self, serializer):
        if not _can_manage_fiscal_years(self.request.user):
            raise PermissionDenied('Only administrators or finance users can update fiscal years.')
        serializer.save()

    def perform_destroy(self, instance):
        if not _can_manage_fiscal_years(self.request.user):
            raise PermissionDenied('Only administrators or finance users can delete fiscal years.')
        instance.delete()
