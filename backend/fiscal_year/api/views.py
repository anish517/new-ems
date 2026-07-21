from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from fiscal_year.models import FiscalYear
from .serializers import FiscalYearSerializer


class FiscalYearListView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = FiscalYearSerializer

    def get_queryset(self):
        org = self.request.user.employee.organization
        return FiscalYear.objects.filter(organization=org)

    def perform_create(self, serializer):
        org = self.request.user.employee.organization
        serializer.save(organization=org)


class FiscalYearDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = FiscalYearSerializer

    def get_queryset(self):
        org = self.request.user.employee.organization
        return FiscalYear.objects.filter(organization=org)