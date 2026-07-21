import datetime
import nepali_datetime
import time
from rest_framework import status
from rest_framework import generics
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from attendance.models import Attendance
from calendar_app.utilities import count_holidays, count_saturdays
from leave_management.models import LeaveRequest
from organization.models import Employee
from salary_management.models import Salary, SalaryTransaction

from .serializers import SalarySerializer, SalaryTransactionSerializer, NetSalarySerializer


class BasicSalaryCreateAPIView(generics.ListCreateAPIView):
    model = Salary
    serializer_class = SalarySerializer
    permission_classes = [IsAuthenticated]

    def create(self, request, *args, **kwargs):
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
        try:
            organization = self.request.user.employee.organization
        except Exception:
            organization = self.request.user.organization.first()
            
        if not organization:
            return Salary.objects.none()
            
        return Salary.objects.filter(organization=organization)


class BasicSalaryUpdateAPIView(generics.UpdateAPIView):
    model = Salary
    serializer_class = SalarySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        employee: Employee = self.request.user.employee
        return Salary.objects.filter(employee__post__department__organization=employee.organization)


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

        net_salary = Salary.calculate_net_salary(
            employee=salary.employee, year=nepali_date.year, month=(nepali_date.month-1))

        # Calculate other details
        no_of_days_present = Attendance.get_no_of_present_days(
            salary.employee, nepali_date.year, nepali_date.month)
        paid_leaves = LeaveRequest.get_total_paid_leaves(
            salary.employee, nepali_date.year, nepali_date.month)
        holidays = count_saturdays(
            nepali_date.year, nepali_date.month) + count_holidays(salary.employee.organization, nepali_date.year, nepali_date.month)

        # Prepare data for the response
        data = {
            "net_salary": net_salary,
            "holidays": holidays,
            "no_of_days_present": no_of_days_present,
            "paid_leaves": paid_leaves,
        }
        serializer = NetSalarySerializer(data)
        return Response(serializer.data, status=status.HTTP_200_OK)


class SalaryTransactionRetrieveAPIView(generics.RetrieveAPIView):
    model = SalaryTransaction
    serializer_class = SalaryTransactionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        time.sleep(2)
        organization = self.request.user.employee.organization
        return SalaryTransaction.objects.filter(organization=organization)


class SalaryTransactionListAPIView(generics.ListAPIView):
    model = SalaryTransaction
    serializer_class = SalaryTransactionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        employee_id = self.request.GET.get('employee')
        try:
            employee = Employee.objects.get(id=employee_id)
        except Employee.DoesNotExist:
            employee = self.request.user.employee

        all_transaction = SalaryTransaction.objects.filter(
            salary__employee=employee).order_by('date')

        return all_transaction

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
        time.sleep(2)
        return Response(data=serializer.data, status=status.HTTP_200_OK)


class OrganizationSalaryTransactionListAPIView(generics.ListCreateAPIView):
    model = SalaryTransaction
    serializer_class = SalaryTransactionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        try:
            organization = self.request.user.employee.organization
        except Exception:
            organization = self.request.user.organization.first()
        return SalaryTransaction.objects.filter(organization=organization).order_by('-date')

    def create(self, request, *args, **kwargs):
        try:
            organization = self.request.user.employee.organization
        except Exception:
            organization = self.request.user.organization.first()
            
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
            
        st = SalaryTransaction.objects.create(
            organization=organization,
            salary=salary,
            fiscal_year=fiscal_year,
            date=date_obj,
            content=content,
            status=status_val
        )
        serializer = self.get_serializer(st)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
