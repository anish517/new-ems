import nepali_datetime
import datetime as dt
from django.utils import timezone
from django.db import models
from rest_framework import status, serializers
from rest_framework import generics
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.exceptions import NotFound
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from leave_management.models import LeaveBalance, LeaveRequest, LeaveType
from .serializers import (
    EmployeeLeaveBalanceSerializer,
    LeaveRequestSerializer,
    LeaveTypeSerializer,
    LeaveBalanceSerializer,
)
from organization.models import Employee


class LeaveTypeListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = LeaveTypeSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        org = None
        if user.organization.exists():
            org = user.organization.first()
        elif hasattr(user, 'employee') and user.employee.organization:
            org = user.employee.organization

        if org:
            return LeaveType.objects.filter(
                models.Q(organization=org) | models.Q(organization__isnull=True)
            ).order_by('id')
        return LeaveType.objects.all().order_by('id')

    def perform_create(self, serializer):
        user = self.request.user
        org = None
        if user.organization.exists():
            org = user.organization.first()
        elif hasattr(user, 'employee'):
            org = user.employee.organization
        serializer.save(organization=org)


class RetrieveLeaveRequestApiView(generics.RetrieveAPIView):
    model = LeaveRequest
    serializer_class = LeaveRequestSerializer
    lookup_field = 'id'

    def get_object(self):
        try:
            obj = LeaveRequest.objects.get(id=self.kwargs[self.lookup_field])
        except LeaveRequest.DoesNotExist:
            raise NotFound(
                f"LeaveRequest with id={self.kwargs[self.lookup_field]} not found.")
        return obj


class UpdateLeaveRequestApiView(generics.RetrieveUpdateDestroyAPIView):
    queryset = LeaveRequest.objects.all()
    serializer_class = LeaveRequestSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = (MultiPartParser, FormParser, JSONParser)

    def patch(self, request, *args, **kwargs):
        instance = self.get_object()
        data = request.data

        action = data.get('action')
        is_initial_approved = data.get('is_initial_approved')
        is_approved = data.get('is_approved')
        is_reviewed = data.get('is_reviewed')
        rejection_reason = data.get('rejection_reason')

        # 1. Initial Approval (for Sick Leave 2-tier approval)
        if action == 'initial_approve' or is_initial_approved is True:
            instance.is_initial_approved = True
            instance.initial_approved_by = request.user
            instance.initial_approved_at = timezone.now()
            instance.save(update_fields=['is_initial_approved', 'initial_approved_by', 'initial_approved_at'])
            return Response(LeaveRequestSerializer(instance, context={'request': request}).data, status=status.HTTP_200_OK)

        # 2. Final Approval
        if action == 'final_approve' or (is_approved is True and (action != 'reject')):
            instance.is_approved = True
            instance.is_reviewed = True
            instance.is_initial_approved = True
            if not instance.initial_approved_by:
                instance.initial_approved_by = request.user
                instance.initial_approved_at = timezone.now()
            instance.rejection_reason = None
            instance.save(update_fields=['is_approved', 'is_reviewed', 'is_initial_approved', 'initial_approved_by', 'initial_approved_at', 'rejection_reason'])
            return Response(LeaveRequestSerializer(instance, context={'request': request}).data, status=status.HTTP_200_OK)

        # 3. Rejection (Mandatory Reason Required)
        if action == 'reject' or (is_reviewed is True and (is_approved is False or is_approved == 'false')):
            reason_str = str(rejection_reason or '').strip()
            if not reason_str:
                return Response(
                    {'error': 'A reason for rejection is required.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            instance.is_approved = False
            instance.is_reviewed = True
            instance.rejection_reason = reason_str
            instance.save(update_fields=['is_approved', 'is_reviewed', 'rejection_reason'])
        # 4. Upload / Update Supporting Document
        if 'document' in request.FILES:
            instance.document = request.FILES['document']
            instance.save(update_fields=['document'])
            return Response(LeaveRequestSerializer(instance, context={'request': request}).data, status=status.HTTP_200_OK)

        # Standard partial update fallback
        return super().partial_update(request, *args, **kwargs)



class EmployeeLeaveCountDetailAPIView(APIView):
    def get(self, request, employee_id, format=None):
        try:
            employee = Employee.objects.get(id=employee_id)
        except:
            return Response({'message': 'Employee not found'}, status=status.HTTP_404_NOT_FOUND)

        from django.db.models import Sum
        ny = request.GET.get('nepali_year')
        current_year = int(ny) if ny else nepali_datetime.datetime.today().year

        all_approved_leave_requests = LeaveRequest.objects.filter(
            employee=employee, is_approved=True, is_reviewed=True
        )

        total_no_of_leaves = sum(lr.no_days for lr in all_approved_leave_requests if getattr(lr.created_at, 'year', None) == current_year)

        leave_types = LeaveType.objects.filter(organization=employee.organization)
        no_of_allowed_leaves = leave_types.aggregate(Sum('quota'))['quota__sum'] or 0

        remaining_leaves = no_of_allowed_leaves - total_no_of_leaves
        if remaining_leaves <= 0:
            remaining_leaves = 0

        data = {
            'no_of_leaves_taken': total_no_of_leaves,
            'remaining_leaves': remaining_leaves,
        }

        return Response(data, status=status.HTTP_200_OK)


class LeaveTypeRetrieveAPIView(generics.RetrieveUpdateDestroyAPIView):
    model = LeaveType
    serializer_class = LeaveTypeSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = 'id'

    def get_object(self):
        try:
            obj = LeaveType.objects.get(id=self.kwargs[self.lookup_field])
        except LeaveType.DoesNotExist:
            raise NotFound("Leave type not found.")
        return obj


class LeaveQuotaRetrieveAPIView(APIView):
    """Returns leave balances for any employee. Accessible by admin and the employee themselves."""
    permission_classes = [IsAuthenticated]

    def get(self, request, employee_id):
        try:
            employee = Employee.objects.get(id=employee_id)
        except Employee.DoesNotExist:
            return Response({"error": "Employee does not exist"}, status=status.HTTP_404_NOT_FOUND)

        leave_balances = LeaveBalance.objects.filter(employee=employee).select_related('leave_type')
        sorted_leave_balances = sorted(
            leave_balances, key=lambda lb: lb.leave_type.name if lb.leave_type else '')

        serializer = EmployeeLeaveBalanceSerializer(
            {"employee": employee, "leave_balances": sorted_leave_balances}
        )
        return Response(data=serializer.data, status=status.HTTP_200_OK)


class LeaveBalanceUpdateAPIView(APIView):
    """Admin: update quota for a specific LeaveBalance record."""
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        try:
            lb = LeaveBalance.objects.get(pk=pk)
        except LeaveBalance.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        quota = request.data.get('quota')
        if quota is None:
            return Response({'error': 'quota is required'}, status=status.HTTP_400_BAD_REQUEST)
        lb.quota = int(quota)
        lb.save(update_fields=['quota'])
        return Response(LeaveBalanceSerializer(lb).data, status=status.HTTP_200_OK)


class AllEmployeeLeaveSummaryView(APIView):
    """Admin: returns a summary of all employees' leave balances."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        org = None
        if user.organization.exists():
            org = user.organization.first()
        elif hasattr(user, 'employee'):
            org = getattr(user.employee, 'organization', None)
        if not org:
            return Response([], status=status.HTTP_200_OK)

        employees = org.employees.select_related('user')
        result = []
        for emp in employees:
            balances = LeaveBalance.objects.filter(employee=emp).select_related('leave_type')
            result.append({
                'employee_id': emp.id,
                'employee_name': emp.user.full_name if emp.user else str(emp),
                'balances': LeaveBalanceSerializer(balances, many=True).data,
            })
        return Response(result, status=status.HTTP_200_OK)


class LeaveRequestListCreateAPIView(generics.ListCreateAPIView):
    model = LeaveRequest
    serializer_class = LeaveRequestSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = (MultiPartParser, FormParser, JSONParser)
    nepali_date_filter_field = 'from_date'

    def get_queryset(self):
        user = self.request.user
        
        is_admin = False
        org = None
        if user.organization.exists():
            is_admin = True
            org = user.organization.first()
        elif getattr(user, 'is_hr', False):
            is_admin = True
            org = getattr(user.employee, 'organization', None) if hasattr(user, 'employee') else None
            if not org:
                from organization.models import Organization
                org = Organization.objects.first()

        try:
            employee = user.employee
            if not org:
                org = employee.organization
        except Exception:
            employee = None
            
        if not org:
            return LeaveRequest.objects.none()

        employeeId = self.request.GET.get('employee', None)
        qs = LeaveRequest.objects.none()
        
        if employeeId:
            try:
                emp = Employee.objects.get(id=employeeId, post__department__organization=org)
                qs = LeaveRequest.objects.filter(organization=org, employee=emp).select_related('type', 'employee__user', 'initial_approved_by').order_by('-id')
            except Employee.DoesNotExist:
                qs = LeaveRequest.objects.none()
        elif is_admin or user.is_superuser:
            qs = LeaveRequest.objects.filter(organization=org).select_related('type', 'employee__user', 'initial_approved_by').order_by('-id')
        elif employee:
            qs = LeaveRequest.objects.filter(organization=org, employee=employee).select_related('type', 'employee__user', 'initial_approved_by').order_by('-id')

        start_date_str = self.request.GET.get('start_date')
        end_date_str = self.request.GET.get('end_date')
        if start_date_str and end_date_str:
            try:
                sy, sm, sd = map(int, start_date_str.split('-'))
                ey, em, ed = map(int, end_date_str.split('-'))
                start_date = nepali_datetime.date(sy, sm, sd)
                end_date = nepali_datetime.date(ey, em, ed)
                qs = qs.filter(from_date__gte=start_date, from_date__lte=end_date)
            except Exception:
                pass
                
        return qs

    def perform_create(self, serializer):
        try:
            employee = self.request.user.employee
        except Exception:
            raise serializers.ValidationError({'detail': 'You must have an employee profile to apply for leave.'})
        
        def to_nepali(date_val):
            if date_val is None:
                return None
            if isinstance(date_val, str):
                y, m, d = map(int, date_val.split('-'))
                return nepali_datetime.date(y, m, d)
            if isinstance(date_val, dt.date):
                return nepali_datetime.date(date_val.year, date_val.month, date_val.day)
            return date_val
        
        from_date = to_nepali(serializer.validated_data.get('from_date'))
        till_date = to_nepali(serializer.validated_data.get('till_date'))
        is_paid = serializer.validated_data.get('is_paid', True)
        is_half_day = serializer.validated_data.get('is_half_day', False)

        if not from_date or not till_date:
            raise serializers.ValidationError({'detail': 'Both from date and till date are required.'})

        if is_half_day:
            requested_days = 0.5
        else:
            if from_date > till_date:
                raise serializers.ValidationError({'detail': 'From date cannot be after Till date.'})
            # Count working days excluding Saturdays (isoweekday == 6)
            days = 0.0
            curr = from_date
            while curr <= till_date:
                try:
                    py_date = curr.to_datetime_date()
                    if py_date.isoweekday() != 6:
                        days += 1.0
                except Exception:
                    days += 1.0
                try:
                    curr = curr + dt.timedelta(days=1)
                except Exception:
                    break
            requested_days = days


        if requested_days <= 0:
            raise serializers.ValidationError({'detail': 'The requested date range contains no working days (e.g. only Saturdays).'})

        # Resolve LeaveType
        leave_type = serializer.validated_data.get('type')
        if not leave_type:
            type_id = self.request.data.get('leave_type_id') or self.request.data.get('type')
            if type_id:
                try:
                    leave_type = LeaveType.objects.get(id=int(type_id))
                except Exception:
                    pass

        if not leave_type:
            cat_name = self.request.data.get('leave_category') or ('Paid Leave' if is_paid else 'Unpaid Leave')
            if employee.organization:
                leave_type = LeaveType.objects.filter(organization=employee.organization, name__iexact=cat_name).first()
            if not leave_type:
                leave_type = LeaveType.objects.filter(name__iexact=cat_name).first()

        # Quota Validation
        if leave_type:
            lb = LeaveBalance.objects.filter(employee=employee, leave_type=leave_type).first()
            if not lb and is_paid:
                lb = LeaveBalance.objects.filter(employee=employee, leave_type__name__iexact='Paid Leave').first()
            elif not lb and not is_paid:
                lb = LeaveBalance.objects.filter(employee=employee, leave_type__name__iexact='Unpaid Leave').first()

            if lb and lb.quota > 0:
                quota = lb.quota or 0
                approved_leaves = LeaveRequest.objects.filter(
                    employee=employee, is_approved=True, is_reviewed=True, type=leave_type
                )
                total_approved = sum(lr.no_days for lr in approved_leaves)

                pending_leaves = LeaveRequest.objects.filter(
                    employee=employee, is_approved=False, is_reviewed=False, type=leave_type
                )
                total_pending = sum(lr.no_days for lr in pending_leaves)

                available_quota = quota - (total_approved + total_pending)
                if requested_days > available_quota:
                    available_display = max(0.0, available_quota)
                    raise serializers.ValidationError({
                        'detail': f'Quota exceeded for {leave_type.name}. You requested {requested_days} day(s), but only have {available_display} day(s) available (Total Quota: {quota}d, Approved: {total_approved}d, Pending: {total_pending}d).'
                    })

        doc_file = self.request.FILES.get('document') or serializer.validated_data.get('document')

        serializer.save(
            employee=employee,
            organization=employee.organization,
            type=leave_type,
            from_date=from_date,
            till_date=till_date,
            is_paid=is_paid,
            remarks=serializer.validated_data.get('remarks', ''),
            document=doc_file,
            is_approved=False,
            is_reviewed=False,
            is_initial_approved=False,
        )


class LeaveBalanceDetailAPIView(generics.RetrieveUpdateAPIView):
    model = LeaveBalance
    serializer_class = LeaveBalanceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        try:
            employee = self.request.user.employee
        except:
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)
            
        org = getattr(employee, 'organization', None)
        if not org and getattr(self.request.user, 'is_hr', False):
            from organization.models import Organization
            org = Organization.objects.first()
            
        return LeaveBalance.objects.filter(organization=org)
