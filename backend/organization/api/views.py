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
                                          DepartmentSerializer, PostSerializer, OrganizationSettingsSerializer, EmployeeProfileChangeRequestSerializer)
from organization.models import (
    Address, BankDetail, Department, Post, Document, Employee, EmployeeAnalysisReport,
    OrganizationFile, NationalIdDetail, Qualification, OrganizationSettings,
    EmployeeProfileChangeRequest)


class DepartmentRetrieveUpdateDeleteAPIView(RetrieveUpdateDestroyAPIView):
    nepali_date_filter_field = False
    serializer_class = DepartmentSerializer
    permission_classes = [IsAuthenticated]
    queryset = Department.objects.all()


class PostListCreateAPIView(ListCreateAPIView):
    nepali_date_filter_field = False
    serializer_class = PostSerializer
    permission_classes = [IsAuthenticated]
    queryset = Post.objects.all()


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
    serializer_class = AddressSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        employee_id = self.request.GET.get('employee')
        if employee_id:
            return Address.objects.filter(employee_id=employee_id)
        return Address.objects.none()

    def create(self, request, *args, **kwargs):
        is_many = isinstance(request.data, list)
        serializer = self.get_serializer(data=request.data, many=is_many)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class EmployeeAddressDetailView(RetrieveUpdateDestroyAPIView):
    nepali_date_filter_field = False
    serializer_class = AddressSerializer
    permission_classes = [IsAuthenticated]
    queryset = Address.objects.all()


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


# ─── Employee Profile Change Requests ──────────────────────────────────────

class ProfileChangeRequestListCreateAPIView(ListCreateAPIView):
    """
    GET  — Employee sees own requests; admin sees all.
    POST — Employee submits a change request for phone_no / personal_email / emergency_phone_number.
    """
    permission_classes = [IsAuthenticated]
    serializer_class = EmployeeProfileChangeRequestSerializer

    def get_queryset(self):
        user = self.request.user
        is_admin = user.organization.exists() or user.is_superuser or user.is_staff or getattr(user, 'is_hr', False)
        if is_admin:
            status_filter = self.request.query_params.get('status')
            qs = EmployeeProfileChangeRequest.objects.select_related('employee__user')
            emp_id = self.request.query_params.get('employee')
            if emp_id:
                qs = qs.filter(employee_id=emp_id)
            if status_filter:
                qs = qs.filter(status=status_filter)
            return qs
        try:
            employee = Employee.objects.get(user=user)
            return EmployeeProfileChangeRequest.objects.filter(employee=employee)
        except Employee.DoesNotExist:
            return EmployeeProfileChangeRequest.objects.none()

    def perform_create(self, serializer):
        from rest_framework.exceptions import PermissionDenied, ValidationError
        user = self.request.user
        try:
            employee = Employee.objects.get(user=user)
        except Employee.DoesNotExist:
            raise PermissionDenied('No employee profile found for current user.')

        field_name = serializer.validated_data.get('field_name')
        allowed = ('phone_no', 'personal_email', 'emergency_phone_number')
        if field_name not in allowed:
            raise ValidationError(f'Only these fields can be changed: {allowed}')

        # Store old value for comparison in admin review
        old_value = getattr(employee, field_name, '') or ''
        serializer.save(employee=employee, old_value=str(old_value))


class AdminProfileChangeRequestActionAPIView(RetrieveUpdateDestroyAPIView):
    """
    POST/PATCH /organization/profile-change-requests/<pk>/action/
    Admin approves or rejects the request. On approval, value is written to Employee.
    """
    permission_classes = [IsAuthenticated]
    serializer_class = EmployeeProfileChangeRequestSerializer
    queryset = EmployeeProfileChangeRequest.objects.select_related('employee__user')
    http_method_names = ['post', 'patch', 'get']
    nepali_date_filter_field = False

    def post(self, request, *args, **kwargs):
        return self.partial_update(request, *args, **kwargs)

    def partial_update(self, request, *args, **kwargs):
        is_admin = request.user.organization.exists() or request.user.is_superuser or request.user.is_staff or getattr(request.user, 'is_hr', False)
        if not is_admin:
            return Response({'error': 'Only admins can review change requests.'}, status=status.HTTP_403_FORBIDDEN)

        instance = self.get_object()
        action = request.data.get('status')
        if action not in ('approved', 'rejected'):
            return Response({'error': 'status must be "approved" or "rejected".'}, status=status.HTTP_400_BAD_REQUEST)

        instance.status = action
        instance.admin_note = request.data.get('admin_note', '')
        instance.reviewed_by = request.user
        instance.save()

        if action == 'approved':
            instance.apply()

        # Notify employee
        try:
            from notification.fcm import notify_user
            field_label = instance.get_field_name_display()
            notify_user(
                user=instance.employee.user,
                notification_type='task',
                title='Profile Change Request Updated',
                body=f'Your request to update {field_label} was {action}.',
                reference_id=instance.id,
            )
        except Exception:
            pass

        serializer = self.get_serializer(instance)
        return Response(serializer.data)

