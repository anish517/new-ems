from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from fiscal_year.models import FiscalYear
from .serializers import FiscalYearSerializer

def _get_org(user):
    try:
        return user.employee.post.department.organization
    except Exception:
        return user.organization.first()

import nepali_datetime

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
        if org and not FiscalYear.objects.filter(organization=org).exists():
            _ensure_default_fiscal_years(org)
        return FiscalYear.objects.filter(organization=org).order_by('-id')

    def perform_create(self, serializer):
        org = _get_org(self.request.user)
        serializer.save(organization=org)


class FiscalYearDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = FiscalYearSerializer

    def get_queryset(self):
        org = _get_org(self.request.user)
        return FiscalYear.objects.filter(organization=org)