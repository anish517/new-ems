import time
import nepali_datetime
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.generics import CreateAPIView, RetrieveAPIView, RetrieveUpdateDestroyAPIView, ListAPIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.authentication import SessionAuthentication

from organization.api.serializers import (BankDetailSerializer, DocumentSerializer, EmployeeAnalysisReportSerializer, EmployeeSerializer,
                                          NationalIDDetailSerializer, OrganizationFileSerializer, AddressSerializer, QualificationSerializer, DepartmentSerializer)
from organization.models import (
    Address, BankDetail, Department, Document, Employee, EmployeeAnalysisReport, OrganizationFile, NationalIdDetail, Qualification)


class DepartmentRetrieveUpdateDeleteAPIView(RetrieveUpdateDestroyAPIView):
    serializer_class = DepartmentSerializer
    permission_classes = [IsAuthenticated]
    queryset = Department.objects.all()


class EmployeeViewSet(viewsets.ModelViewSet):
    queryset = Employee.objects.all()
    serializer_class = EmployeeSerializer
    permission_classes = [IsAuthenticated]


class EmployeeAddressCreateView(CreateAPIView):
    "API view to create new employee address"
    serializer_class = AddressSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data, many=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class EmployeeAddressDetailView(RetrieveUpdateDestroyAPIView):
    serializer_class = AddressSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        pk = self.kwargs['pk']
        return Address.objects.filter(pk=pk)


class NationalIdViewSet(viewsets.ModelViewSet):
    queryset = NationalIdDetail.objects.all()
    serializer_class = NationalIDDetailSerializer
    permission_classes = [IsAuthenticated]


class QualificationViewSet(viewsets.ModelViewSet):
    queryset = Qualification.objects.all()
    serializer_class = QualificationSerializer
    permission_classes = [IsAuthenticated]


class BankDetailViewSet(viewsets.ModelViewSet):
    queryset = BankDetail.objects.all()
    serializer_class = BankDetailSerializer
    permission_classes = [IsAuthenticated]


class DocumentViewSet(viewsets.ModelViewSet):
    queryset = Document.objects.all()
    serializer_class = DocumentSerializer
    permission_classes = [IsAuthenticated]


class EmployeeAnalysisReportListAPIView(ListAPIView):
    serializer_class = EmployeeAnalysisReportSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        employee_id = self.request.GET.get('employee')
        try:
            employee = Employee.objects.get(id=employee_id)
        except Employee.DoesNotExist:
            employee = self.request.user.employee

        return EmployeeAnalysisReport.objects.filter(employee=employee).order_by('date')

    def list(self, request, *args, **kwargs):
        year = int(self.request.GET.get(
            'year', nepali_datetime.date.today().year))

        qs = self.get_queryset()
        yearly_reports = []
        for report in qs:
            if report.date.year == year:
                yearly_reports.append(report)
        serializer = self.get_serializer(yearly_reports, many=True)
        time.sleep(2)
        return Response(data=serializer.data, status=status.HTTP_200_OK)


class OrganizationFileRetrieveAPIView(RetrieveAPIView):
    serializer_class = OrganizationFileSerializer

    def get_queryset(self):
        return OrganizationFile.objects.filter(organization=self.request.user.employee.organization)

    def get_object(self):
        queryset = self.get_queryset()
        return get_object_or_404(queryset, pk=self.kwargs['pk'])

from rest_framework.views import APIView
from organization.models import OrganizationAddress

class SetOrganizationAddressView(APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        lat = request.data.get('latitude')
        lng = request.data.get('longitude')
        
        if lat is None or lng is None:
            return Response({'error': 'Latitude and longitude are required.'}, status=status.HTTP_400_BAD_REQUEST)
            
        # Try to get organization from employee profile, or user's first organization
        org = None
        try:
            org = request.user.employee.organization
        except Exception:
            orgs = request.user.organization.all()
            if orgs.exists():
                org = orgs.first()
            elif request.user.is_superuser:
                from organization.models import Organization
                org = Organization.objects.first()
                
        if not org:
            return Response({'error': 'You do not belong to any organization.'}, status=status.HTTP_400_BAD_REQUEST)
            
        # Update or create the primary address
        address, created = OrganizationAddress.objects.update_or_create(
            organization=org,
            primary=True,
            defaults={
                'latitude': lat,
                'longitude': lng,
                'state': 'bagmati', # default required field
                'address_line_1': 'Head Office',
                'address_line_2': ''
            }
        )
        return Response({'message': 'Organization address configured successfully.'}, status=status.HTTP_200_OK)
