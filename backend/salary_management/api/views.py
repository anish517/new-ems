import datetime
import nepali_datetime
import time
from rest_framework import status
from rest_framework import generics
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import permissions
from django.http import HttpResponse
import csv
from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import TokenError, InvalidToken
from django.contrib.auth import get_user_model

from attendance.models import Attendance
from calendar_app.utilities import count_holidays, count_saturdays
from leave_management.models import LeaveRequest
from organization.models import Employee
from salary_management.models import Salary, SalaryTransaction

from .serializers import SalarySerializer, SalaryTransactionSerializer, NetSalarySerializer

class IsSalaryAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        if user.is_superuser:
            return True
        if user.organization.exists():
            return True
        return False

def _get_org(user):
    try:
        return user.employee.post.department.organization
    except Exception:
        return user.organization.first()


class BasicSalaryCreateAPIView(generics.ListCreateAPIView):
    model = Salary
    serializer_class = SalarySerializer
    permission_classes = [IsAuthenticated]

    def create(self, request, *args, **kwargs):
        # Only admins can create salaries
        if not IsSalaryAdmin().has_permission(request, self):
            return Response({'error': 'Not authorized to create salary'}, status=status.HTTP_403_FORBIDDEN)
            
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        employee = serializer.validated_data.get('employee')
        
        salary, created = Salary.objects.update_or_create(
            employee=employee,
            defaults={
                'basic_salary': serializer.validated_data.get('basic_salary', 0),
                'remote_salary': serializer.validated_data.get('remote_salary', 0),
                'organization': employee.organization if hasattr(employee, 'organization') else None
            }
        )
        return Response(self.get_serializer(salary).data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)

    def get_queryset(self):
        user = self.request.user
        
        # If admin, return all salaries in org
        if IsSalaryAdmin().has_permission(self.request, self):
            organization = _get_org(user)
            if not organization:
                return Salary.objects.none()
            return Salary.objects.filter(organization=organization)
            
        # If employee, return only their salary
        if hasattr(user, 'employee'):
            return Salary.objects.filter(employee=user.employee)
            
        return Salary.objects.none()


class BasicSalaryUpdateAPIView(generics.UpdateAPIView):
    model = Salary
    serializer_class = SalarySerializer
    permission_classes = [IsSalaryAdmin]

    def get_queryset(self):
        organization = _get_org(self.request.user)
        return Salary.objects.filter(organization=organization)


class NetSalaryAPIView(generics.RetrieveAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, salary_id):
        nepali_date = nepali_datetime.date.today()
        selected_date = request.GET.get('date', None)

        if selected_date:
            date = datetime.datetime.strptime(selected_date, "%Y-%m-%d").date()
            nepali_date = nepali_datetime.date(
                year=date.year, month=date.month, day=1)
        try:
            salary = Salary.objects.get(id=salary_id)
        except Salary.DoesNotExist:
            return Response({'error': 'Salary details not found'}, status=status.HTTP_404_NOT_FOUND)
            
        user = request.user
        is_admin = user.is_superuser or user.organization.exists()
        if not is_admin and salary.employee != getattr(user, 'employee', None):
            return Response({'error': 'You do not have permission to view this salary.'}, status=status.HTTP_403_FORBIDDEN)

        # Use the same year/month for all calculations for consistency
        year = nepali_date.year
        month = nepali_date.month

        net_salary = Salary.calculate_net_salary(
            employee=salary.employee, year=year, month=month)

        # Calculate other details (same month as net salary)
        no_of_days_present = Attendance.get_no_of_present_days(
            salary.employee, year, month)
        paid_leaves = LeaveRequest.get_total_paid_leaves(
            salary.employee, year, month)
        holidays = count_saturdays(
            year, month) + count_holidays(salary.employee.organization, year, month)
        unpaid_leaves = LeaveRequest.get_total_unpaid_leaves(
            salary.employee, year, month)
        half_leaves = LeaveRequest.get_total_half_leaves(
            salary.employee, year, month)

        # Prepare data for the response
        data = {
            "net_salary": net_salary,
            "holidays": holidays,
            "no_of_days_present": no_of_days_present,
            "paid_leaves": paid_leaves,
            "unpaid_leaves": unpaid_leaves,
            "half_leaves": half_leaves,
        }
        serializer = NetSalarySerializer(data)
        return Response(serializer.data, status=status.HTTP_200_OK)


class SalaryTransactionRetrieveAPIView(generics.RetrieveUpdateDestroyAPIView):
    model = SalaryTransaction
    serializer_class = SalaryTransactionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        organization = _get_org(self.request.user)
        return SalaryTransaction.objects.filter(organization=organization)


class SalaryTransactionListAPIView(generics.ListAPIView):
    model = SalaryTransaction
    serializer_class = SalaryTransactionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        employee_id = self.request.GET.get('employee')
        
        is_admin = user.is_superuser or user.organization.exists()
        if not is_admin:
            try:
                employee_id = user.employee.id
            except Exception:
                return SalaryTransaction.objects.none()

        if not employee_id:
            try:
                employee_id = user.employee.id
            except Exception:
                return SalaryTransaction.objects.none()

        try:
            employee = Employee.objects.get(id=employee_id)
        except Employee.DoesNotExist:
            return SalaryTransaction.objects.none()

        return SalaryTransaction.objects.filter(salary__employee=employee).order_by('date')

    def list(self, request, *args, **kwargs):
        selected_year = self.request.GET.get('year', None)
        qs = self.get_queryset()
        yearly_transaction_history = []

        if selected_year:
            current_year = int(selected_year)
        else:
            current_year = nepali_datetime.date.today().year

        for transaction in qs:
            if transaction.date.year == current_year:
                yearly_transaction_history.append(transaction)
        serializer = self.get_serializer(yearly_transaction_history, many=True)
        return Response(data=serializer.data, status=status.HTTP_200_OK)


class OrganizationSalaryTransactionListAPIView(generics.ListCreateAPIView):
    model = SalaryTransaction
    serializer_class = SalaryTransactionSerializer
    permission_classes = [IsSalaryAdmin]

    def get_queryset(self):
        organization = _get_org(self.request.user)
        qs = SalaryTransaction.objects.filter(organization=organization).order_by('-date')
        # Allow filtering by employee ID for the admin employee detail view
        employee_id = self.request.GET.get('employee')
        if employee_id:
            qs = qs.filter(salary__employee_id=employee_id)
        return qs

    def create(self, request, *args, **kwargs):
        organization = _get_org(self.request.user)
            
        # Extract data from request
        salary_id = request.data.get('salary')
        fiscal_year_id = request.data.get('fiscal_year')
        date_str = request.data.get('date') # Format: YYYY-MM-DD
        content = request.data.get('content', '')
        status_val = request.data.get('status', True)
        
        from salary_management.models import Salary
        from fiscal_year.models import FiscalYear
        
        salary = Salary.objects.get(id=salary_id)
        fiscal_year = FiscalYear.objects.get(id=fiscal_year_id)
        
        # Parse nepali date
        if date_str:
            y, m, d = map(int, date_str.split('-'))
            date_obj = nepali_datetime.date(y, m, d)
        else:
            date_obj = nepali_datetime.date.today()
            
        manual_net = request.data.get('net_salary')
        if manual_net is not None:
            try:
                manual_net = float(manual_net)
            except ValueError:
                manual_net = None

        st = SalaryTransaction.objects.create(
            organization=organization,
            salary=salary,
            fiscal_year=fiscal_year,
            date=date_obj,
            content=content,
            status=status_val,
            manual_net_salary=manual_net
        )
        serializer = self.get_serializer(st)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

class GenerateSalaryReportAPIView(generics.GenericAPIView):
    permission_classes = [IsSalaryAdmin]

    def get(self, request):

        year_str = request.GET.get('year')
        month_str = request.GET.get('month')
        if not year_str or not month_str:
            return Response({'error': 'Year and month query parameters are required.'}, status=status.HTTP_400_BAD_REQUEST)
            
        year = int(year_str)
        month = int(month_str)

        try:
            organization = request.user.employee.organization
        except Exception:
            organization = None

        if organization:
            salaries = Salary.objects.filter(organization=organization)
        else:
            salaries = Salary.objects.all()

        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="salary_report_{year}_{month}.csv"'

        writer = csv.writer(response)
        writer.writerow(['Employee Name', 'Email', 'Basic Salary', 'Remote Salary', 'Days Present', 'Paid Leaves', 'Unpaid Leaves', 'Half Leaves', 'Net Salary'])

        for salary in salaries:
            # Check if a manual/issued salary transaction exists for this month
            emp_transactions = SalaryTransaction.objects.filter(salary=salary)
            transaction = next((t for t in emp_transactions if getattr(t.date, 'year', None) == year and getattr(t.date, 'month', None) == month), None)
            
            if transaction:
                net_salary = transaction.net_salary
            else:
                net_salary = Salary.calculate_net_salary(employee=salary.employee, year=year, month=month)
                
            no_of_days_present = Attendance.get_no_of_present_days(salary.employee, year, month)
            paid_leaves = LeaveRequest.get_total_paid_leaves(salary.employee, year, month)
            unpaid_leaves = LeaveRequest.get_total_unpaid_leaves(salary.employee, year, month)
            half_leaves = LeaveRequest.get_total_half_leaves(salary.employee, year, month)
            
            writer.writerow([
                str(salary.employee),
                salary.employee.user.email,
                salary.basic_salary,
                salary.remote_salary,
                no_of_days_present,
                paid_leaves,
                unpaid_leaves,
                half_leaves,
                net_salary
            ])

        return response
