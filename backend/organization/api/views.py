import time
import csv
import nepali_datetime
from django.shortcuts import get_object_or_404
from django.http import HttpResponse
from rest_framework import status
from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.generics import CreateAPIView, RetrieveAPIView, RetrieveUpdateDestroyAPIView, ListAPIView, ListCreateAPIView
from rest_framework.permissions import IsAuthenticated, AllowAny
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
        
        # Also sync directly to OrganizationSettings for Geofencing attendance validation
        from organization.models import OrganizationSettings
        settings_obj, _ = OrganizationSettings.objects.get_or_create(organization=org)
        settings_obj.office_latitude = lat
        settings_obj.office_longitude = lng
        settings_obj.save(update_fields=['office_latitude', 'office_longitude'])
        
        return Response({
            'message': 'Organization address & GPS Geofence coordinates configured successfully.',
            'office_latitude': lat,
            'office_longitude': lng
        }, status=status.HTTP_200_OK)


class EmployeeReportAPIView(APIView):
    permission_classes = [AllowAny]
    
    def get(self, request, employee_id):
        import csv
        from django.http import HttpResponse
        from attendance.models import Attendance
        from salary_management.models import SalaryTransaction
        
        # Authenticate via Header or Query Token
        user = request.user
        if not user or not user.is_authenticated:
            token = request.GET.get('token')
            if token:
                try:
                    from rest_framework_simplejwt.authentication import JWTAuthentication
                    validated = JWTAuthentication().get_validated_token(token)
                    user = JWTAuthentication().get_user(validated)
                except Exception:
                    pass
        if not user or not user.is_authenticated:
            return Response({'error': 'Authentication credentials were not provided.'}, status=status.HTTP_401_UNAUTHORIZED)
        
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
            try:
                total_secs = att.total_working_hours[1] if isinstance(att.total_working_hours, tuple) else 0
            except Exception:
                total_secs = 0
            
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


class EmployeeExportCSVAPIView(APIView):
    """
    Export full employee directory to CSV including PAN, designation, bank, and statutory details.
    """
    permission_classes = [AllowAny]
    nepali_date_filter_field = False

    def get(self, request):
        import csv
        from django.http import HttpResponse
        from organization.models import BankDetail

        # Authenticate via Header or Query Token
        user = request.user
        if not user or not user.is_authenticated:
            token = request.GET.get('token') or request.headers.get('Authorization', '').replace('Bearer ', '')
            if token:
                try:
                    from rest_framework_simplejwt.authentication import JWTAuthentication
                    validated = JWTAuthentication().get_validated_token(token)
                    user = JWTAuthentication().get_user(validated)
                except Exception:
                    pass
        if not user or not user.is_authenticated:
            return Response({'error': 'Authentication credentials were not provided.'}, status=status.HTTP_401_UNAUTHORIZED)

        org = None
        if hasattr(user, 'organization') and user.organization.exists():
            org = user.organization.first()
        elif getattr(user, 'is_superuser', False) or getattr(user, 'is_hr', False):
            from organization.models import Organization
            org = Organization.objects.first()

        if org:
            employees = Employee.objects.filter(post__department__organization=org)
        else:
            employees = Employee.objects.all()

        response = HttpResponse(content_type='text/csv; charset=utf-8')
        response['Content-Disposition'] = 'attachment; filename="employee_directory.csv"'
        response.write('\ufeff')  # UTF-8 BOM for Excel

        writer = csv.writer(response)
        writer.writerow([
            'Employee ID',
            'Full Name',
            'Official Email',
            'Personal Email',
            'Phone No',
            'PAN Number',
            'Designation',
            'Employee Type',
            'Gender',
            'Marital Status',
            'Date of Birth (B.S.)',
            'Father Name',
            'Grandfather Name',
            'Blood Group',
            'Emergency Contact',
            'Bank Name',
            'Account Holder',
            'Account Number',
            'Status'
        ])

        for emp in employees.select_related('user', 'post', 'post__department').order_by('id'):
            user_obj = emp.user
            bank = BankDetail.objects.filter(employee=emp).first()

            full_name = f"{user_obj.first_name} {user_obj.last_name}".strip() if user_obj else ''
            if not full_name and user_obj:
                full_name = user_obj.email

            writer.writerow([
                emp.get_id,
                full_name,
                emp.official_email or (user_obj.email if user_obj else ''),
                emp.personal_email or '',
                emp.phone_no or '',
                emp.pan_number or '',
                emp.post.title if emp.post else '',
                emp.get_employee_type_display() if hasattr(emp, 'get_employee_type_display') else (emp.employee_type or ''),
                emp.get_gender_display() if hasattr(emp, 'get_gender_display') else (emp.gender or ''),
                emp.get_marital_status_display() if hasattr(emp, 'get_marital_status_display') else (emp.marital_status or ''),
                str(emp.date_of_birth) if emp.date_of_birth else '',
                emp.father_name or '',
                emp.grandfather_name or '',
                emp.blood_group or '',
                emp.emergency_phone_number or '',
                bank.bank_name if bank else '',
                bank.account_name if bank else '',
                bank.account_number if bank else '',
                'Active' if emp.is_active else 'Archived'
            ])

        return response


class OrganizationSettingsView(RetrieveUpdateDestroyAPIView):
    """Retrieve or update the settings for the authenticated user's organization."""
    serializer_class = OrganizationSettingsSerializer
    permission_classes = [IsAuthenticated]
    nepali_date_filter_field = False

    def get_object(self):
        user = self.request.user
        org = None
        try:
            org = user.employee.organization
        except Exception:
            pass
        if not org and user.organization.exists():
            org = user.organization.first()
        if not org and user.is_superuser:
            from organization.models import Organization
            org = Organization.objects.first()

        if not org:
            from rest_framework.exceptions import NotFound
            raise NotFound(detail="No organization found.")

        settings, _ = OrganizationSettings.objects.get_or_create(organization=org)
        if (settings.office_latitude is None or settings.office_longitude is None) and org.address.exists():
            addr = org.address.filter(primary=True).first() or org.address.first()
            if addr and (addr.latitude != 0 or addr.longitude != 0):
                settings.office_latitude = addr.latitude
                settings.office_longitude = addr.longitude
                settings.save(update_fields=['office_latitude', 'office_longitude'])
        return settings

    def perform_update(self, serializer):
        instance = serializer.save()
        if instance.office_latitude is not None and instance.office_longitude is not None:
            # Sync to primary OrganizationAddress as well
            OrganizationAddress.objects.update_or_create(
                organization=instance.organization,
                primary=True,
                defaults={
                    'latitude': instance.office_latitude,
                    'longitude': instance.office_longitude,
                    'state': 'bagmati',
                    'address_line_1': 'Head Office',
                    'address_line_2': ''
                }
            )


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


# ─── Employee CSV Export & Bulk Import ──────────────────────────────────────────

# ─── Employee CSV Export & Bulk Import ──────────────────────────────────────────




class EmployeeSampleCSVAPIView(APIView):
    """
    GET /api/organization/employees/sample-csv/
    Downloads a sample CSV template for bulk employee import.
    """
    permission_classes = [AllowAny]
    nepali_date_filter_field = False

    def get(self, request, *args, **kwargs):
        response = HttpResponse(content_type='text/csv; charset=utf-8')
        response['Content-Disposition'] = 'attachment; filename="employee_import_sample_template.csv"'
        response.write('\ufeff')

        writer = csv.writer(response)
        writer.writerow([
            'First Name', 'Last Name', 'Official Email', 'Password', 'Phone No',
            'PAN Number', 'Designation', 'Employee Type', 'Gender',
            'Marital Status', 'Date of Birth (B.S.)', 'Father Name', 'Grandfather Name',
            'Blood Group', 'Emergency Contact', 'Personal Email'
        ])
        writer.writerow([
            'Aarav', 'Sharma', 'aarav.sharma@company.com', 'Staff@1234', '9841234567',
            '102938475', 'Senior Flutter Developer', 'full_time', 'male',
            'single', '2055-04-12', 'Ram Sharma', 'Hari Sharma',
            'A+', '9801234567', 'aarav.personal@gmail.com'
        ])
        writer.writerow([
            'Sita', 'Adhikari', 'sita.adhikari@company.com', 'Staff@1234', '9851098765',
            '987654321', 'UI/UX Designer', 'full_time', 'female',
            'married', '2056-08-20', 'Gopal Adhikari', 'Krishna Adhikari',
            'O+', '9812345678', 'sita.personal@gmail.com'
        ])
        return response


class EmployeeImportCSVAPIView(APIView):
    """
    POST /api/organization/employees/import-csv/
    Uploads and bulk imports employees from a CSV file.
    Creates new accounts/employees or updates existing matches by email.
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    nepali_date_filter_field = False

    def post(self, request, *args, **kwargs):
        user = request.user
        is_admin = user.organization.exists() or user.is_superuser or user.is_staff or getattr(user, 'is_hr', False)
        if not is_admin:
            return Response({'error': 'Only administrators and HR can import employee records.'}, status=status.HTTP_403_FORBIDDEN)

        csv_file = request.FILES.get('file')
        if not csv_file:
            return Response({'error': 'No CSV file provided. Please upload a .csv file using the "file" field.'}, status=status.HTTP_400_BAD_REQUEST)

        if not csv_file.name.lower().endswith('.csv'):
            return Response({'error': 'Invalid file format. Only CSV (.csv) files are supported.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            decoded_file = csv_file.read().decode('utf-8-sig').splitlines()
        except Exception:
            try:
                csv_file.seek(0)
                decoded_file = csv_file.read().decode('latin-1').splitlines()
            except Exception as e:
                return Response({'error': f'Failed to read CSV file: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)

        reader = csv.DictReader(decoded_file)
        if not reader.fieldnames:
            return Response({'error': 'CSV file is empty or missing header row.'}, status=status.HTTP_400_BAD_REQUEST)

        # Normalize header keys mapping
        normalized_headers = {}
        for fn in reader.fieldnames:
            if not fn:
                continue
            clean = fn.strip().lower().replace(' ', '_').replace('-', '_').replace('(', '').replace(')', '').replace('.', '')
            normalized_headers[fn] = clean

        created_count = 0
        updated_count = 0
        errors = []

        from organization.models import Organization
        org = user.organization.first() if user.organization.exists() else Organization.objects.first()

        default_dept = Department.objects.first()
        if not default_dept and org:
            default_dept = Department.objects.create(department_name='General', organization=org)

        default_post = Post.objects.first()
        if not default_post:
            default_post = Post.objects.create(title='Staff Member', department=default_dept)

        from authentication.models import Account

        for row_idx, raw_row in enumerate(reader, start=2):
            row = {}
            for k, v in raw_row.items():
                if k is not None:
                    norm_k = normalized_headers.get(k, k.strip().lower().replace(' ', '_'))
                    row[norm_k] = (v.strip() if isinstance(v, str) else '')

            # Email identification
            email = (row.get('official_email') or row.get('email') or row.get('work_email') or '').strip()
            first_name = (row.get('first_name') or row.get('fname') or '').strip()
            last_name = (row.get('last_name') or row.get('lname') or '').strip()
            full_name = (row.get('full_name') or row.get('name') or '').strip()

            if not first_name and full_name:
                parts = full_name.split(' ', 1)
                first_name = parts[0]
                last_name = parts[1] if len(parts) > 1 else ''

            if not email:
                errors.append(f"Row {row_idx}: Skipped (Official Email is required).")
                continue

            phone = (row.get('phone_no') or row.get('phone') or row.get('phone_number') or row.get('primary_phone') or '').strip()
            pan = (row.get('pan_number') or row.get('pan') or row.get('pan_no') or '').strip()
            gender = (row.get('gender') or 'male').strip().lower()
            if gender not in ('male', 'female', 'others'):
                gender = 'male'
            marital_status = (row.get('marital_status') or 'single').strip().lower()
            if marital_status not in ('single', 'married'):
                marital_status = 'single'
            employee_type = (row.get('employee_type') or 'full_time').strip().lower().replace(' ', '_').replace('-', '_')
            if employee_type not in ('full_time', 'part_time', 'intern'):
                employee_type = 'full_time'
            dob = (row.get('date_of_birth_bs') or row.get('date_of_birth') or row.get('dob') or '2055-01-01').strip()
            father_name = (row.get('father_name') or row.get('fathers_name') or '').strip()
            grandfather_name = (row.get('grandfather_name') or row.get('grandfathers_name') or '').strip()
            blood_group = (row.get('blood_group') or 'A+').strip()
            emergency_phone = (row.get('emergency_contact') or row.get('emergency_phone') or row.get('emergency_phone_number') or '').strip()
            personal_email = (row.get('personal_email') or '').strip()
            desig_name = (row.get('designation') or row.get('post') or row.get('job_role') or '').strip()
            password = (row.get('password') or 'Staff@1234').strip()

            # Resolve post / designation
            post = default_post
            if desig_name:
                post = Post.objects.filter(title__iexact=desig_name).first()
                if not post:
                    post = Post.objects.create(title=desig_name, department=default_dept)

            try:
                user_obj = Account.objects.filter(email__iexact=email).first()
                if user_obj:
                    if first_name:
                        user_obj.first_name = first_name
                    if last_name:
                        user_obj.last_name = last_name
                    user_obj.save()

                    emp_obj = Employee.objects.filter(user=user_obj).first()
                    if emp_obj:
                        emp_obj.post = post
                        if phone: emp_obj.phone_no = phone
                        if pan: emp_obj.pan_number = pan
                        emp_obj.gender = gender
                        emp_obj.marital_status = marital_status
                        emp_obj.employee_type = employee_type
                        if dob: emp_obj.date_of_birth = dob
                        if father_name: emp_obj.father_name = father_name
                        if grandfather_name: emp_obj.grandfather_name = grandfather_name
                        if blood_group: emp_obj.blood_group = blood_group
                        if emergency_phone: emp_obj.emergency_phone_number = emergency_phone
                        if personal_email: emp_obj.personal_email = personal_email
                        emp_obj.official_email = email
                        emp_obj.save()
                        updated_count += 1
                    else:
                        Employee.objects.create(
                            user=user_obj,
                            post=post,
                            phone_no=phone,
                            pan_number=pan,
                            gender=gender,
                            marital_status=marital_status,
                            employee_type=employee_type,
                            date_of_birth=dob,
                            father_name=father_name,
                            grandfather_name=grandfather_name,
                            blood_group=blood_group,
                            emergency_phone_number=emergency_phone,
                            personal_email=personal_email,
                            official_email=email,
                            is_active=True,
                        )
                        created_count += 1
                else:
                    new_user = Account.objects.create_user(
                        email=email,
                        password=password,
                        first_name=first_name or 'Staff',
                        last_name=last_name or 'Member',
                    )
                    Employee.objects.create(
                        user=new_user,
                        post=post,
                        phone_no=phone,
                        pan_number=pan,
                        gender=gender,
                        marital_status=marital_status,
                        employee_type=employee_type,
                        date_of_birth=dob,
                        father_name=father_name,
                        grandfather_name=grandfather_name,
                        blood_group=blood_group,
                        emergency_phone_number=emergency_phone,
                        personal_email=personal_email,
                        official_email=email,
                        is_active=True,
                    )
                    created_count += 1
            except Exception as row_err:
                errors.append(f"Row {row_idx} ({email}): {str(row_err)}")

        return Response({
            'message': f'Bulk CSV import finished. {created_count} employee(s) created, {updated_count} updated.',
            'created_count': created_count,
            'updated_count': updated_count,
            'errors': errors,
        }, status=status.HTTP_200_OK if (created_count > 0 or updated_count > 0 or not errors) else status.HTTP_400_BAD_REQUEST)


