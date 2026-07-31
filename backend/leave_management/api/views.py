import nepali_datetime
import time
from rest_framework import status, serializers
from rest_framework import generics
from rest_framework.views import APIView
from rest_framework.exceptions import NotFound
from leave_management.models import LeaveBalance, LeaveRequest, LeaveType
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from .serializers import EmployeeLeaveBalanceSerializer, LeaveRequestSerializer, LeaveTypeSerializer, LeaveBalanceSerializer
from organization.models import Employee



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


class EmployeeLeaveCountDetailAPIView(APIView):
    def get(self, request, employee_id, format=None):
        try:
            employee = Employee.objects.get(id=employee_id)
        except:
            employee = None
            return Response({'message': 'Employee not found'}, status=status.HTTP_404_NOT_FOUND)

        from django.db.models import Sum
        ny = request.GET.get('nepali_year')
        current_year = int(ny) if ny else nepali_datetime.datetime.today().year

        all_approved_leave_requests = LeaveRequest.objects.filter(
            employee=employee, is_approved=True, is_reviewed=True
        )

        total_no_of_leaves = sum(lr.no_days for lr in all_approved_leave_requests if getattr(lr.created_at, 'year', None) == current_year)

        leave_types = LeaveType.objects.filter(organization=employee.organization)
        no_of_allowed_leaves = leave_types.aggregate(Sum('maximum_leave'))['maximum_leave__sum'] or 0

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
            raise NotFound(f"Leave type not found.")
        return obj

    def update(self, request, *args, **kwargs):
        return super().update(request, *args, **kwargs)

    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


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
    nepali_date_filter_field = 'from_date'

    def get_queryset(self):
        user = self.request.user
        
        # Check if user is an admin
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

        # Check for specific employee filter
        employeeId = self.request.GET.get('employee', None)
        qs = LeaveRequest.objects.none()
        
        if employeeId:
            try:
                emp = Employee.objects.get(id=employeeId, post__department__organization=org)
                qs = LeaveRequest.objects.filter(organization=org, employee=emp).order_by('-id')
            except Employee.DoesNotExist:
                qs = LeaveRequest.objects.none()
        elif is_admin or user.is_superuser:
            qs = LeaveRequest.objects.filter(organization=org).order_by('-id')
        elif employee:
            qs = LeaveRequest.objects.filter(organization=org, employee=employee).order_by('-id')

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
        
        # Convert Gregorian dates to Nepali dates
        import datetime as dt
        import nepali_datetime
        
        def to_nepali(date_val):
            if date_val is None:
                return None
            if isinstance(date_val, str):
                y, m, d = map(int, date_val.split('-'))
                return nepali_datetime.date(y, m, d)
            if isinstance(date_val, dt.date):
                # DRF might parse a Nepali date string "2083-04-15" into a Gregorian dt.date(2083, 4, 15).
                # We extract the components directly instead of converting it from Gregorian.
                return nepali_datetime.date(date_val.year, date_val.month, date_val.day)
            return date_val
        
        from_date = to_nepali(serializer.validated_data.get('from_date'))
        till_date = to_nepali(serializer.validated_data.get('till_date'))
        
        serializer.save(
            employee=employee,
            organization=employee.organization,
            from_date=from_date,
            till_date=till_date,
            remarks=serializer.validated_data.get('remarks', ''),
            is_approved=False,
            is_reviewed=False,
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

    def update(self, request, *args, **kwargs):
        return super().update(request, *args, **kwargs)
