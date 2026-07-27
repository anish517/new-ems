import datetime
import nepali_datetime
import time
from rest_framework import status
from rest_framework import generics
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import permissions
from django.http import HttpResponse
from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.conf import settings
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

        # Parse overrides
        try:
            holidays_override = int(request.GET.get('holidays')) if request.GET.get('holidays') is not None else None
        except ValueError:
            holidays_override = None

        try:
            ssf_override = float(request.GET.get('ssf')) if request.GET.get('ssf') is not None else None
        except ValueError:
            ssf_override = None

        try:
            epf_override = float(request.GET.get('epf')) if request.GET.get('epf') is not None else None
        except ValueError:
            epf_override = None

        try:
            tds_override = float(request.GET.get('tds')) if request.GET.get('tds') is not None else None
        except ValueError:
            tds_override = None
            
        try:
            incentive_override = float(request.GET.get('incentive')) if request.GET.get('incentive') is not None else 0
        except ValueError:
            incentive_override = 0

        net_salary = Salary.calculate_net_salary(
            employee=salary.employee, year=year, month=month,
            holidays_override=holidays_override,
            ssf_override=ssf_override,
            epf_override=epf_override,
            tds_override=tds_override)
            
        net_salary += incentive_override

        # Calculate other details (same month as net salary)
        no_of_days_present = Attendance.get_no_of_present_days(
            salary.employee, year, month)
        paid_leaves = LeaveRequest.get_total_paid_leaves(
            salary.employee, year, month)
        holidays = holidays_override if holidays_override is not None else (count_saturdays(
            year, month) + count_holidays(salary.employee.organization, year, month))
        unpaid_leaves = LeaveRequest.get_total_unpaid_leaves(
            salary.employee, year, month)
        half_leaves = LeaveRequest.get_total_half_leaves(
            salary.employee, year, month)

        gross_salary = Salary.calculate_gross_salary(
            employee=salary.employee, year=year, month=month, holidays_override=holidays_override)
        tax_rate = salary.tax_rate or 0
        tds_amount = tds_override if tds_override is not None else (round((gross_salary * tax_rate) / 100) if tax_rate > 0 else (salary.tds or 0))
        ssf = ssf_override if ssf_override is not None else (salary.ssf or 0)
        epf = epf_override if epf_override is not None else (salary.epf or 0)

        # Prepare data for the response
        data = {
            "net_salary": net_salary,
            "holidays": holidays,
            "no_of_days_present": no_of_days_present,
            "paid_leaves": paid_leaves,
            "unpaid_leaves": unpaid_leaves,
            "half_leaves": half_leaves,
            "tds": tds_amount,
            "ssf": ssf,
            "epf": epf,
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
        start_date_str = self.request.GET.get('start_date')
        end_date_str = self.request.GET.get('end_date')
        
        qs = self.get_queryset()
        yearly_transaction_history = []
        
        if start_date_str and end_date_str:
            try:
                sy, sm, sd = map(int, start_date_str.split('-'))
                ey, em, ed = map(int, end_date_str.split('-'))
                start_date = nepali_datetime.date(sy, sm, sd)
                end_date = nepali_datetime.date(ey, em, ed)
                for transaction in qs:
                    if start_date <= transaction.date <= end_date:
                        yearly_transaction_history.append(transaction)
            except Exception:
                pass
        else:
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
        
        employee_id = self.request.GET.get('employee')
        if employee_id:
            qs = qs.filter(salary__employee_id=employee_id)
            
        start_date_str = self.request.GET.get('start_date')
        end_date_str = self.request.GET.get('end_date')
        if start_date_str and end_date_str:
            try:
                sy, sm, sd = map(int, start_date_str.split('-'))
                ey, em, ed = map(int, end_date_str.split('-'))
                qs = qs.filter(date__gte=nepali_datetime.date(sy, sm, sd), date__lte=nepali_datetime.date(ey, em, ed))
            except Exception:
                pass
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

        incentive = request.data.get('incentive', 0)
        try:
            incentive = float(incentive)
        except (ValueError, TypeError):
            incentive = 0.0

        email_preference = request.data.get('email_preference', 'none')  # 'official', 'personal', 'both', 'none'

        try:
            holidays_val = int(request.data.get('holidays')) if request.data.get('holidays') is not None else None
        except ValueError:
            holidays_val = None

        try:
            ssf_val = float(request.data.get('ssf')) if request.data.get('ssf') is not None else None
        except ValueError:
            ssf_val = None

        try:
            epf_val = float(request.data.get('epf')) if request.data.get('epf') is not None else None
        except ValueError:
            epf_val = None

        try:
            tds_val = float(request.data.get('tds')) if request.data.get('tds') is not None else None
        except ValueError:
            tds_val = None

        st = SalaryTransaction.objects.create(
            organization=organization,
            salary=salary,
            fiscal_year=fiscal_year,
            date=date_obj,
            content=content,
            status=status_val,
            manual_net_salary=manual_net,
            incentive=incentive,
            stored_holidays=holidays_val,
            transaction_ssf=ssf_val,
            transaction_epf=epf_val,
            transaction_tds=tds_val,
        )

        # ── Send salary slip email ──────────────────────────────────────────
        if email_preference != 'none':
            try:
                employee = salary.employee
                employee_name = employee.user.full_name
                # Use emails configured from the Add Employee form
                official_email = getattr(employee, 'official_email', None) or employee.user.email
                personal_email = getattr(employee, 'personal_email', None) or official_email

                nepali_months = [
                    '', 'Baishakh', 'Jestha', 'Ashadh', 'Shrawan',
                    'Bhadra', 'Ashwin', 'Kartik', 'Mangsir',
                    'Poush', 'Magh', 'Falgun', 'Chaitra'
                ]
                month_name = nepali_months[date_obj.month] if date_obj.month <= 12 else str(date_obj.month)

                tax_rate = salary.tax_rate or 0
                gross = st.gross_salary
                tds_amount = st.transaction_tds if st.transaction_tds is not None else (round((gross * tax_rate) / 100) if tax_rate > 0 else (salary.tds or 0))
                ssf = st.transaction_ssf if st.transaction_ssf is not None else (salary.ssf or 0)
                epf = st.transaction_epf if st.transaction_epf is not None else (salary.epf or 0)
                total_deductions = tds_amount + ssf + epf

                subject = f'Salary Slip — {month_name} {date_obj.year} | EMS'
                message_text = (
                    f'Dear {employee_name},\n\n'
                    f'Your salary for {month_name} {date_obj.year} has been processed.\n'
                    f'  Gross Salary    : NPR {gross:,.0f}\n'
                    f'  Incentive       : NPR {incentive:,.0f}\n'
                    f'  TDS ({tax_rate}%)     : NPR {tds_amount:,.0f}\n'
                    f'  SSF             : NPR {ssf:,.0f}\n'
                    f'  EPF             : NPR {epf:,.0f}\n'
                    f'  Total Deductions: NPR {total_deductions:,.0f}\n'
                    f'  NET SALARY PAID : NPR {st.net_salary:,.0f}\n\n'
                    f'Thank you,\nEMS HR Team'
                )

                html_message = f"""<!DOCTYPE html>
<html><head><style>
body{{font-family:'Segoe UI',sans-serif;background:#f4f7f6;margin:0;padding:0;}}
.wrap{{max-width:600px;margin:40px auto;background:#fff;border-radius:8px;overflow:hidden;box-shadow:0 4px 15px rgba(0,0,0,.06);border:1px solid #e0e6ed;}}
.hdr{{background:linear-gradient(135deg,#1e3c72,#2a5298);color:#fff;text-align:center;padding:30px 20px;}}
.hdr h1{{margin:0;font-size:22px;letter-spacing:1px;}}
.hdr p{{margin:4px 0 0;font-size:13px;opacity:.9;}}
.body{{padding:28px 30px;}}
.hi{{font-size:17px;margin-bottom:16px;color:#2c3e50;}}
.box{{background:#f8fafc;border-left:4px solid #2a5298;padding:14px 18px;margin-bottom:22px;border-radius:0 4px 4px 0;}}
.box h2{{margin:0 0 4px;font-size:15px;color:#475569;}}
.net{{font-size:26px;font-weight:700;color:#10b981;margin:0;}}
table{{width:100%;border-collapse:collapse;margin-bottom:18px;}}
th,td{{padding:11px 14px;text-align:left;border-bottom:1px solid #e2e8f0;font-size:14px;}}
th{{background:#f1f5f9;color:#64748b;font-weight:600;font-size:12px;text-transform:uppercase;}}
.amt{{text-align:right;font-family:monospace;}}
.ded{{color:#ef4444;}}
.tr-bold td{{font-weight:700;color:#0f172a;}}
.footer{{background:#f8fafc;text-align:center;padding:18px;font-size:12px;color:#94a3b8;border-top:1px solid #e2e8f0;}}
</style></head><body>
<div class='wrap'>
  <div class='hdr'><h1>Salary Payslip</h1><p>For {month_name}, {date_obj.year}</p></div>
  <div class='body'>
    <div class='hi'>Hello <strong>{employee_name}</strong>,</div>
    <p style='color:#64748b;font-size:14px;line-height:1.6;'>Your salary for <strong>{month_name} {date_obj.year}</strong> has been successfully processed. Below is your detailed salary breakdown.</p>
    <div class='box'><h2>Net Salary Payable</h2><p class='net'>NPR {st.net_salary:,.0f}</p></div>
    <table>
      <thead><tr><th colspan='2'>Earnings</th></tr></thead>
      <tbody>
        <tr><td>Basic (Gross) Salary</td><td class='amt'>NPR {gross:,.0f}</td></tr>
        <tr><td>Performance Incentive</td><td class='amt'>NPR {incentive:,.0f}</td></tr>
        <tr class='tr-bold'><td>Total Earnings</td><td class='amt'>NPR {gross + incentive:,.0f}</td></tr>
      </tbody>
    </table>
    <table>
      <thead><tr><th colspan='2'>Deductions</th></tr></thead>
      <tbody>
        <tr><td>TDS ({tax_rate}%)</td><td class='amt ded'>- NPR {tds_amount:,.0f}</td></tr>
        <tr><td>SSF</td><td class='amt ded'>- NPR {ssf:,.0f}</td></tr>
        <tr><td>EPF</td><td class='amt ded'>- NPR {epf:,.0f}</td></tr>
        <tr class='tr-bold'><td>Total Deductions</td><td class='amt ded'>- NPR {total_deductions:,.0f}</td></tr>
      </tbody>
    </table>
  </div>
  <div class='footer'><p>This is an automatically generated email from your Employee Management System.</p><p>&copy; 2026 EMS. All rights reserved.</p></div>
</div></body></html>"""

                recipients = []
                if email_preference in ('official', 'both'):
                    recipients.append(official_email)
                if email_preference in ('personal', 'both'):
                    if personal_email and personal_email not in recipients:
                        recipients.append(personal_email)

                if recipients:
                    send_mail(
                        subject=subject,
                        message=message_text,
                        from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', 'noreply@ems.local'),
                        recipient_list=recipients,
                        html_message=html_message,
                        fail_silently=False,
                    )
            except Exception as e:
                print(f'[EMS] Email dispatch error: {e}')
        # ───────────────────────────────────────────────────────────────────

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
