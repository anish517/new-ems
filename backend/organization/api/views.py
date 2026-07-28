import time
import nepali_datetime
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.generics import CreateAPIView, RetrieveAPIView, RetrieveUpdateDestroyAPIView, ListAPIView, ListCreateAPIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.authentication import SessionAuthentication

from rest_framework.decorators import action
from organization.api.serializers import (BankDetailSerializer, DocumentSerializer, EmployeeAnalysisReportSerializer, EmployeeSerializer,
                                          NationalIDDetailSerializer, OrganizationFileSerializer, AddressSerializer, QualificationSerializer,
                                          DepartmentSerializer, OrganizationSettingsSerializer)
from organization.models import (
    Address, BankDetail, Department, Document, Employee, EmployeeAnalysisReport,
    OrganizationFile, NationalIdDetail, Qualification, OrganizationSettings)


class DepartmentRetrieveUpdateDeleteAPIView(RetrieveUpdateDestroyAPIView):
    nepali_date_filter_field = False
    serializer_class = DepartmentSerializer
    permission_classes = [IsAuthenticated]
    queryset = Department.objects.all()


class EmployeeViewSet(viewsets.ModelViewSet):
    nepali_date_filter_field = False
    serializer_class = EmployeeSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # For retrieve/update/destroy: use all_objects so archived employees are accessible
        if self.action in ('retrieve', 'update', 'partial_update', 'destroy'):
            return Employee.all_objects.all()
            
        # Determine base manager based on time-travel or archived status request
        is_time_travel = self.request.query_params.get('nepali_year') and self.request.query_params.get('nepali_month')
        is_archived = self.request.query_params.get('status') == 'archived'
        base_manager = Employee.all_objects if (is_time_travel or is_archived) else Employee.objects
        
        # For list: filtered by org securely
        user = self.request.user
        if user.organization.exists():
            return base_manager.filter(
                post__department__organization=user.organization.first()
            )
        try:
            return base_manager.filter(
                post__department__organization=user.employee.organization
            )
        except Exception:
            return base_manager.all()

    def perform_destroy(self, instance):
        user = instance.user
        if instance.is_deleted:
            # If already soft-deleted, perform a hard delete
            instance.hard_delete()
            if user:
                user.delete() # Completely delete the user account too
        else:
            # First time: soft delete
            instance.delete()
            if user:
                user.is_active = False
                user.save()

    @action(detail=True, methods=['post'])
    def reset_password(self, request, pk=None):
        employee = self.get_object()
        new_password = request.data.get('password')
        if not new_password:
            return Response({'error': 'Password is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        user = employee.user
        user.set_password(new_password)
        user.save()
        return Response({'message': 'Password updated successfully'}, status=status.HTTP_200_OK)


class EmployeeAddressCreateView(ListCreateAPIView):
    nepali_date_filter_field = False
    "API view to list and create employee addresses"
    serializer_class = AddressSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        employee_id = self.request.GET.get('employee')
        if employee_id:
            return Address.objects.filter(employee_id=employee_id)
        return Address.objects.none()

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data, many=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class EmployeeAddressDetailView(RetrieveUpdateDestroyAPIView):
    nepali_date_filter_field = False
    serializer_class = AddressSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        pk = self.kwargs['pk']
        return Address.objects.filter(pk=pk)


class NationalIdViewSet(viewsets.ModelViewSet):
    nepali_date_filter_field = False
    queryset = NationalIdDetail.objects.all()
    serializer_class = NationalIDDetailSerializer
    permission_classes = [IsAuthenticated]


class QualificationViewSet(viewsets.ModelViewSet):
    nepali_date_filter_field = False
    queryset = Qualification.objects.all()
    serializer_class = QualificationSerializer
    permission_classes = [IsAuthenticated]


class BankDetailViewSet(viewsets.ModelViewSet):
    nepali_date_filter_field = False
    queryset = BankDetail.objects.all()
    serializer_class = BankDetailSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = BankDetail.objects.all()
        employee_id = self.request.query_params.get('employee')
        if employee_id:
            qs = qs.filter(employee_id=employee_id)
        return qs


class DocumentViewSet(viewsets.ModelViewSet):
    nepali_date_filter_field = False
    queryset = Document.objects.all()
    serializer_class = DocumentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = Document.objects.all()
        employee_id = self.request.query_params.get('employee')
        if employee_id:
            qs = qs.filter(employee_id=employee_id)
        return qs


class EmployeeAnalysisReportListAPIView(ListAPIView):
    nepali_date_filter_field = False
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
        qs = self.get_queryset()
        
        start_date_str = self.request.GET.get('start_date')
        end_date_str = self.request.GET.get('end_date')
        if start_date_str and end_date_str:
            try:
                sy, sm, sd = map(int, start_date_str.split('-'))
                ey, em, ed = map(int, end_date_str.split('-'))
                start_date = nepali_datetime.date(sy, sm, sd)
                end_date = nepali_datetime.date(ey, em, ed)
                qs = qs.filter(date__gte=start_date, date__lte=end_date)
                serializer = self.get_serializer(qs, many=True)
                return Response(data=serializer.data, status=status.HTTP_200_OK)
            except Exception:
                pass

        year = int(self.request.GET.get(
            'year', nepali_datetime.date.today().year))

        yearly_reports = []
        for report in qs:
            if report.date.year == year:
                yearly_reports.append(report)
        serializer = self.get_serializer(yearly_reports, many=True)
        return Response(data=serializer.data, status=status.HTTP_200_OK)


class OrganizationFileRetrieveAPIView(RetrieveAPIView):
    nepali_date_filter_field = False
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


class EmployeeReportAPIView(APIView):
    permission_classes = [IsAuthenticated]
    
    def get(self, request, employee_id):
        import csv
        from django.http import HttpResponse
        from attendance.models import Attendance
        from salary_management.models import SalaryTransaction
        
        start_date_str = request.GET.get('start_date')
        end_date_str = request.GET.get('end_date')
        
        try:
            employee = Employee.objects.get(id=employee_id)
        except Employee.DoesNotExist:
            return Response({'error': 'Employee not found.'}, status=status.HTTP_404_NOT_FOUND)
            
        attendances = Attendance.objects.filter(employee=employee).order_by('date')
        transactions = SalaryTransaction.objects.filter(salary__employee=employee).order_by('date')
        
        if start_date_str and end_date_str:
            try:
                sy, sm, sd = map(int, start_date_str.split('-'))
                ey, em, ed = map(int, end_date_str.split('-'))
                start_date = nepali_datetime.date(sy, sm, sd)
                end_date = nepali_datetime.date(ey, em, ed)
                
                attendances = attendances.filter(date__gte=start_date, date__lte=end_date)
                transactions = transactions.filter(date__gte=start_date, date__lte=end_date)
            except Exception:
                pass
                
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="employee_report_{employee_id}.csv"'
        
        writer = csv.writer(response)
        
        # Attendance section
        writer.writerow(['ATTENDANCE DATA'])
        writer.writerow(['Date', 'Check In', 'Check Out', 'Is Remote', 'Status', 'Working Hours'])
        for att in attendances:
            first_ci = att.check_ins_outs.order_by('id').first()
            last_co = att.check_ins_outs.order_by('-id').first()
            ci_time = first_ci.check_in if first_ci else '-'
            co_time = last_co.check_out if (last_co and last_co.check_out) else '-'
            _, total_secs = att.total_working_hours
            
            writer.writerow([
                str(att.date),
                ci_time,
                co_time,
                'Yes' if att.is_remote else 'No',
                'Present' if att.has_checked_in() else 'Absent',
                round(total_secs / 3600, 2)
            ])
            
        writer.writerow([])
        writer.writerow(['SALARY DATA'])
        writer.writerow(['Date', 'Fiscal Year', 'Content', 'Net Salary', 'Status'])
        for txn in transactions:
            writer.writerow([
                str(txn.date),
                str(txn.fiscal_year),
                txn.content,
                txn.net_salary,
                'Paid' if txn.status else 'Pending'
            ])
            
        return response


class OrganizationSettingsView(RetrieveUpdateDestroyAPIView):
    """Retrieve or update the settings for the authenticated user's organization."""
    serializer_class = OrganizationSettingsSerializer
    permission_classes = [IsAuthenticated]
    nepali_date_filter_field = False

    def get_object(self):
        user = self.request.user
        if user.organization.exists():
            org = user.organization.first()
        else:
            return Response({"detail": "No organization found."}, status=404)
        settings, _ = OrganizationSettings.objects.get_or_create(organization=org)
        return settings
