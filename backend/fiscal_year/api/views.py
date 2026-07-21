from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from fiscal_year.models import FiscalYear
from .serializers import FiscalYearSerializer

def _get_org(user):
    try:
        return user.employee.post.department.organization
    except Exception:
        return user.organization.first()

class FiscalYearListView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = FiscalYearSerializer

    def get_queryset(self):
        org = _get_org(self.request.user)
        return FiscalYear.objects.filter(organization=org)

    def perform_create(self, serializer):
        org = _get_org(self.request.user)
        serializer.save(organization=org)


class FiscalYearDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = FiscalYearSerializer

    def get_queryset(self):
        org = _get_org(self.request.user)
        return FiscalYear.objects.filter(organization=org)