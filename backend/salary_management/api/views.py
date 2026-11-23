import datetime
import nepali_datetime
import time
from rest_framework import status
from rest_framework import generics
from rest_framework.views import APIView
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
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
from calendar_app.utilities import count_holidays, count_saturdays, total_days_in_month
from leave_management.models import LeaveRequest
from organization.models import Employee, Organization
from salary_management.models import (
    Salary, SalaryTransaction, SalaryTaxBand, IncentiveTaxBand, BonusTaxBand,
    FinanceAccess, get_tax_from_bands,
)

from .serializers import (
    SalarySerializer, SalaryTransactionSerializer, NetSalarySerializer,
    SalaryTaxBandSerializer, IncentiveTaxBandSerializer, BonusTaxBandSerializer,
    FinanceAccessSerializer, FinanceAccessCreateSerializer,
)


def _get_active_finance_access(user):
    if not user or not user.is_authenticated:
        return None
    if not getattr(user, 'is_finance', False):
        return None
    try:
        access = user.finance_access
        return access if access and access.is_active else None
    except Exception:
        return None


def _is_strict_salary_admin(user):
    return bool(
        user
        and user.is_authenticated
        and (user.is_superuser or user.organization.exists())
    )


def _is_finance_or_admin(user):
    return _is_strict_salary_admin(user) or _get_active_finance_access(user) is not None


class IsStrictSalaryAdmin(permissions.BasePermission):
    """Only Super Admin / Org Admin (used for managing Finance user accounts)."""
    def has_permission(self, request, view):
        return _is_strict_salary_admin(request.user)


class IsSalaryAdmin(permissions.BasePermission):
    """Super Admin, Org Admin, or active Finance account."""
    def has_permission(self, request, view):
        return _is_finance_or_admin(request.user)


class IsSalaryAdminOrHR(permissions.BasePermission):
    """Super Admin, Org Admin, HR, or active Finance account."""
    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        if _is_finance_or_admin(user):
            return True
        if getattr(user, 'is_hr', False):
            return True
        return False


def _get_org(user):
    """Resolve the tenant for the salary views.

    Checks Employee post, Organization admin_users, active FinanceAccess,
    and falls back to first Organization for superusers / HR.
    """
    try:
        return user.employee.post.department.organization
    except Exception:
        pass
    if user.organization.exists():
        return user.organization.first()
    finance_access = _get_active_finance_access(user)
    if finance_access and finance_access.organization:
        return finance_access.organization
    if getattr(user, 'is_superuser', False) or getattr(user, 'is_hr', False):
        return Organization.objects.first()
    return None


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

        org = _get_org(request.user)
        emp_org = getattr(employee, 'organization', None)
        if org and emp_org and emp_org.id != org.id:
            return Response({'error': 'Employee does not belong to your organization.'}, status=status.HTTP_403_FORBIDDEN)
        
        defaults = {
            'basic_salary': serializer.validated_data.get('basic_salary', 0),
            'remote_salary': serializer.validated_data.get('remote_salary', 0),
            'organization': emp_org or org,
        }
        for optional_field in ('ssf', 'tds', 'epf', 'citizen_investment_trust', 'insurance', 'tax_rate'):
            if optional_field in serializer.validated_data:
                defaults[optional_field] = serializer.validated_data.get(optional_field) or 0

        salary, created = Salary.objects.update_or_create(
            employee=employee,
            defaults=defaults,
        )
        return Response(self.get_serializer(salary).data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)

    def get_queryset(self):
        user = self.request.user
        
        # If admin or finance, return all salaries in org
        if IsSalaryAdmin().has_permission(self.request, self):
            organization = _get_org(user)
            if not organization:
                return Salary.objects.none()
            return Salary.objects.filter(organization=organization).order_by('-id')
            
        # If employee, return only their salary
        if hasattr(user, 'employee'):
            return Salary.objects.filter(employee=user.employee).order_by('-id')
            
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
        req_year = request.GET.get('year', None)
        req_month = request.GET.get('month', None)

        if req_year and req_month:
            try:
                nepali_date = nepali_datetime.date(
                    year=int(req_year), month=int(req_month), day=1)
            except Exception:
                pass
        elif selected_date:
            date = datetime.datetime.strptime(selected_date, "%Y-%m-%d").date()
            nepali_date = nepali_datetime.date(
                year=date.year, month=date.month, day=1)
        try:
            salary = Salary.objects.get(id=salary_id)
        except Salary.DoesNotExist:
            return Response({'error': 'Salary details not found'}, status=status.HTTP_404_NOT_FOUND)
            
        user = request.user
        is_payroll_manager = _is_finance_or_admin(user)
        if is_payroll_manager:
            org = _get_org(user)
            if org and salary.organization_id and salary.organization_id != org.id:
                return Response({'error': 'You do not have permission to view this salary.'}, status=status.HTTP_403_FORBIDDEN)
        elif salary.employee != getattr(user, 'employee', None):
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

        try:
            bonus_override = float(request.GET.get('bonus')) if request.GET.get('bonus') is not None else 0
        except ValueError:
            bonus_override = 0

        net_salary = Salary.calculate_net_salary(
            employee=salary.employee, year=year, month=month,
            holidays_override=holidays_override,
            ssf_override=ssf_override,
            epf_override=epf_override,
            tds_override=tds_override,
            incentive_override=incentive_override,
            bonus_override=bonus_override)
            
        net_salary += incentive_override + bonus_override

        # Calculate other details (same month as net salary)
        no_of_days_present = Attendance.get_no_of_present_days(
            salary.employee, year, month)
        paid_leaves = LeaveRequest.get_total_paid_leaves(
            salary.employee, year, month)
        
        # Determine active start day for this month based on joining date
        joined_year, joined_month, joined_day = Salary.get_employee_joining_bs(salary.employee)
        start_day = 1
        days_in_month = total_days_in_month(year, month)
        if joined_year:
            if year < joined_year or (year == joined_year and month < joined_month):
                start_day = days_in_month + 1
            elif year == joined_year and month == joined_month:
                start_day = max(1, min(joined_day, days_in_month))

        holidays = holidays_override if holidays_override is not None else (count_saturdays(
            year, month, start_day=start_day) + count_holidays(salary.employee.organization, year, month, start_day=start_day))
        unpaid_leaves = LeaveRequest.get_total_unpaid_leaves(
            salary.employee, year, month)
        half_leaves = LeaveRequest.get_total_half_leaves(
            salary.employee, year, month)

        gross_salary = Salary.calculate_gross_salary(
            employee=salary.employee, year=year, month=month, holidays_override=holidays_override)
        tds_amount = Salary.calculate_tds(
            employee=salary.employee,
            year=year,
            month=month,
            gross_salary=gross_salary,
            holidays_override=holidays_override,
            tds_override=tds_override,
            incentive_override=incentive_override,
            bonus_override=bonus_override,
        )
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
        user = self.request.user
        if _is_finance_or_admin(user):
            organization = _get_org(user)
            return SalaryTransaction.objects.filter(organization=organization) if organization else SalaryTransaction.objects.none()
        if hasattr(user, 'employee'):
            return SalaryTransaction.objects.filter(salary__employee=user.employee)
        return SalaryTransaction.objects.none()

    def perform_update(self, serializer):
        if not _is_finance_or_admin(self.request.user):
            raise PermissionDenied('Only administrators or finance users can update salary transactions.')
        serializer.save()

    def perform_destroy(self, instance):
        if not _is_finance_or_admin(self.request.user):
            raise PermissionDenied('Only administrators or finance users can delete salary transactions.')
        instance.delete()


class SalaryTransactionListAPIView(generics.ListAPIView):
    model = SalaryTransaction
    serializer_class = SalaryTransactionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        employee_id = self.request.GET.get('employee')
        
        is_payroll_manager = _is_finance_or_admin(user)
        if not is_payroll_manager:
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

        if is_payroll_manager:
            org = _get_org(user)
            emp_org = employee.organization
            if org and emp_org and emp_org.id != org.id:
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
                from calendar_app.utilities import total_days_in_month
                sy, sm, sd = map(int, start_date_str.split('-'))
                ey, em, ed = map(int, end_date_str.split('-'))
                sd = max(1, min(sd, total_days_in_month(sy, sm)))
                ed = max(1, min(ed, total_days_in_month(ey, em)))
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
        if employee_id and employee_id != 'null':
            qs = qs.filter(salary__employee_id=employee_id)
            
        start_date_str = self.request.GET.get('start_date')
        end_date_str = self.request.GET.get('end_date')
        if start_date_str and end_date_str:
            try:
                from calendar_app.utilities import total_days_in_month
                sy, sm, sd = map(int, start_date_str.split('-'))
                ey, em, ed = map(int, end_date_str.split('-'))
                sd = max(1, min(sd, total_days_in_month(sy, sm)))
                ed = max(1, min(ed, total_days_in_month(ey, em)))
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
        
        try:
            salary = Salary.objects.get(id=salary_id)
        except Salary.DoesNotExist:
            return Response({'error': 'Salary record not found.'}, status=status.HTTP_404_NOT_FOUND)
        if organization and salary.organization_id and salary.organization_id != organization.id:
            return Response({'error': 'Salary record does not belong to your organization.'}, status=status.HTTP_403_FORBIDDEN)

        try:
            fiscal_year = FiscalYear.objects.get(id=fiscal_year_id)
        except FiscalYear.DoesNotExist:
            return Response({'error': 'Fiscal year not found.'}, status=status.HTTP_404_NOT_FOUND)
        if organization and fiscal_year.organization_id and fiscal_year.organization_id != organization.id:
            return Response({'error': 'Fiscal year does not belong to your organization.'}, status=status.HTTP_403_FORBIDDEN)
        
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

        bonus = request.data.get('bonus', 0)
        try:
            bonus = float(bonus)
        except (ValueError, TypeError):
            bonus = 0.0

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
            raw_tds = request.data.get('tds')
            tds_val = float(raw_tds) if (raw_tds is not None and str(raw_tds).strip() != '') else None
        except (ValueError, TypeError):
            tds_val = None

        # Note: When tds_val is None, SalaryTransaction.save() automatically calls
        # Salary.calculate_tds() which combines base salary progressive-band TDS
        # with IncentiveTaxBand and BonusTaxBand TDS.

        st = SalaryTransaction.objects.create(
            organization=organization,
            salary=salary,
            fiscal_year=fiscal_year,
            date=date_obj,
            content=content,
            status=status_val,
            manual_net_salary=manual_net,
            incentive=incentive,
            bonus=bonus,
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
                incentive_amt = st.incentive or 0
                bonus_amt = st.bonus or 0
                tds_amount = st.transaction_tds if st.transaction_tds is not None else (round((gross * tax_rate) / 100) if tax_rate > 0 else (salary.tds or 0))
                ssf = st.transaction_ssf if st.transaction_ssf is not None else (salary.ssf or 0)
                epf = st.transaction_epf if st.transaction_epf is not None else (salary.epf or 0)

                # Separate incentive & bonus taxes for display
                incentive_tax_display = 0.0
                bonus_tax_display = 0.0
                if incentive_amt > 0:
                    inc_bands = IncentiveTaxBand.objects.filter(organization=st.organization)
                    if inc_bands.exists():
                        incentive_tax_display = get_tax_from_bands(inc_bands, incentive_amt)
                if bonus_amt > 0:
                    bon_bands = BonusTaxBand.objects.filter(organization=st.organization)
                    if bon_bands.exists():
                        bonus_tax_display = get_tax_from_bands(bon_bands, bonus_amt)

                salary_tds = tds_amount - incentive_tax_display - bonus_tax_display
                total_deductions = tds_amount + ssf + epf

                subject = f'Salary Slip — {month_name} {date_obj.year} | EMS'
                message_text = (
                    f'Dear {employee_name},\n\n'
                    f'Your salary for {month_name} {date_obj.year} has been processed.\n'
                    f'  Gross Salary       : NPR {gross:,.0f}\n'
                    f'  Incentive          : NPR {incentive_amt:,.0f}\n'
                    f'  Bonus              : NPR {bonus_amt:,.0f}\n'
                    f'  Salary TDS         : NPR {max(salary_tds, 0):,.0f}\n'
                    f'  Incentive TDS      : NPR {incentive_tax_display:,.0f}\n'
                    f'  Bonus TDS          : NPR {bonus_tax_display:,.0f}\n'
                    f'  SSF                : NPR {ssf:,.0f}\n'
                    f'  EPF                : NPR {epf:,.0f}\n'
                    f'  Total Deductions   : NPR {total_deductions:,.0f}\n'
                    f'  NET SALARY PAID    : NPR {st.net_salary:,.0f}\n\n'
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
        <tr><td>Performance Incentive</td><td class='amt'>NPR {incentive_amt:,.0f}</td></tr>
        <tr><td>Bonus</td><td class='amt'>NPR {bonus_amt:,.0f}</td></tr>
        <tr class='tr-bold'><td>Total Earnings</td><td class='amt'>NPR {gross + incentive_amt + bonus_amt:,.0f}</td></tr>
      </tbody>
    </table>
    <table>
      <thead><tr><th colspan='2'>Deductions</th></tr></thead>
      <tbody>
        <tr><td>Salary TDS</td><td class='amt ded'>- NPR {max(salary_tds, 0):,.0f}</td></tr>
        <tr><td>Incentive TDS</td><td class='amt ded'>- NPR {incentive_tax_display:,.0f}</td></tr>
        <tr><td>Bonus TDS</td><td class='amt ded'>- NPR {bonus_tax_display:,.0f}</td></tr>
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
    # Was AllowAny with no authorization check after resolving the user, which
    # let any authenticated employee export org-wide salary data.
    permission_classes = [IsSalaryAdminOrHR]

    def get(self, request):
        # ?token= is resolved globally by base.query_param_auth.QueryParamJWTAuthentication,
        # so request.user is already populated for browser-initiated downloads.
        user = request.user

        year_str = request.GET.get('year')
        month_str = request.GET.get('month')
        start_date_str = request.GET.get('start_date')
        end_date_str = request.GET.get('end_date')
        employee_id = request.GET.get('employee')

        try:
            organization = _get_org(user)
        except Exception:
            organization = None

        # Fail closed. Every queryset below applies its organization filter
        # conditionally, so a None here silently reported across all tenants.
        if not organization:
            return Response({'error': 'No organization could be resolved for this account.'}, status=status.HTTP_400_BAD_REQUEST)

        response = HttpResponse(content_type='text/csv')

        if start_date_str and end_date_str:
            # New Advanced Report (Date Range filtered by issued transactions)
            try:
                from calendar_app.utilities import total_days_in_month
                sy, sm, sd = map(int, start_date_str.split('-'))
                ey, em, ed = map(int, end_date_str.split('-'))
                if not (1 <= sm <= 12 and 1 <= em <= 12 and 1 <= sd <= 32 and 1 <= ed <= 32):
                    raise ValueError('Out of bounds')
                sd = min(sd, total_days_in_month(sy, sm))
                ed = min(ed, total_days_in_month(ey, em))
                start_date = nepali_datetime.date(sy, sm, sd)
                end_date = nepali_datetime.date(ey, em, ed)
            except Exception:
                return Response({'error': 'Invalid date format'}, status=status.HTTP_400_BAD_REQUEST)

            response['Content-Disposition'] = f'attachment; filename="salary_report_{start_date_str}_to_{end_date_str}.csv"'
            writer = csv.writer(response)
            writer.writerow(['Date', 'Employee Name', 'Email', 'PAN Number', 'Basic Salary', 'Remote Salary', 'Days Present',
                             'Paid Leaves', 'Unpaid Leaves', 'Half Leaves',
                             'Incentive', 'Bonus', 'Salary TDS', 'Incentive TDS', 'Bonus TDS', 'Total TDS', 'Net Salary'])
            
            qs = SalaryTransaction.objects.filter(
                date__gte=start_date,
                date__lte=end_date,
                salary__isnull=False,
                salary__employee__isnull=False
            )
            if organization:
                qs = qs.filter(organization=organization)
            if employee_id and employee_id != 'null':
                qs = qs.filter(salary__employee_id=employee_id)
                
            for transaction in qs.order_by('-date'):
                salary = transaction.salary
                if not salary or not getattr(salary, 'employee', None):
                    continue
                employee = salary.employee
                user_obj = getattr(employee, 'user', None)
                if not user_obj:
                    continue

                year = transaction.date.year if transaction.date else 2083
                month = transaction.date.month if transaction.date else 1
                
                no_of_days_present = transaction.stored_no_of_days_present if transaction.stored_no_of_days_present is not None else Attendance.get_no_of_present_days(employee, year, month)
                paid_leaves = transaction.stored_paid_leaves if transaction.stored_paid_leaves is not None else LeaveRequest.get_total_paid_leaves(employee, year, month)
                unpaid_leaves = transaction.stored_unpaid_leaves if transaction.stored_unpaid_leaves is not None else LeaveRequest.get_total_unpaid_leaves(employee, year, month)
                half_leaves = transaction.stored_half_leaves if transaction.stored_half_leaves is not None else LeaveRequest.get_total_half_leaves(employee, year, month)
                
                incentive_amt = transaction.incentive or 0
                bonus_amt = transaction.bonus or 0
                total_tds = transaction.transaction_tds or 0

                incentive_tax = 0.0
                bonus_tax = 0.0
                if incentive_amt > 0 and organization:
                    inc_bands = IncentiveTaxBand.objects.filter(organization=organization)
                    if inc_bands.exists():
                        incentive_tax = get_tax_from_bands(inc_bands, incentive_amt)
                if bonus_amt > 0 and organization:
                    bon_bands = BonusTaxBand.objects.filter(organization=organization)
                    if bon_bands.exists():
                        bonus_tax = get_tax_from_bands(bon_bands, bonus_amt)
                        
                salary_tds = total_tds - incentive_tax - bonus_tax
                
                writer.writerow([
                    str(transaction.date),
                    str(user_obj.full_name or user_obj.username),
                    user_obj.email or '',
                    getattr(employee, 'pan_number', '') or '',
                    salary.basic_salary or 0,
                    salary.remote_salary or 0,
                    no_of_days_present,
                    paid_leaves,
                    unpaid_leaves,
                    half_leaves,
                    incentive_amt,
                    bonus_amt,
                    salary_tds,
                    incentive_tax,
                    bonus_tax,
                    total_tds,
                    transaction.net_salary
                ])
            return response

        elif year_str and month_str:
            # Legacy Monthly Report (Projection)
            year = int(year_str)
            month = int(month_str)

            if organization:
                salaries = Salary.objects.filter(organization=organization, employee__isnull=False)
            else:
                salaries = Salary.objects.filter(employee__isnull=False)

            response['Content-Disposition'] = f'attachment; filename="salary_report_{year}_{month}.csv"'
            writer = csv.writer(response)
            writer.writerow(['Employee Name', 'Email', 'PAN Number', 'Basic Salary', 'Remote Salary', 'Days Present',
                             'Paid Leaves', 'Unpaid Leaves', 'Half Leaves',
                             'Incentive', 'Bonus', 'Total TDS', 'Net Salary'])

            for salary in salaries:
                if not getattr(salary, 'employee', None):
                    continue
                employee = salary.employee
                user_obj = getattr(employee, 'user', None)
                if not user_obj:
                    continue

                emp_transactions = SalaryTransaction.objects.filter(salary=salary)
                transaction = next((t for t in emp_transactions if getattr(t.date, 'year', None) == year and getattr(t.date, 'month', None) == month), None)

                if transaction:
                    net_salary = transaction.net_salary
                    incentive_csv = transaction.incentive or 0
                    bonus_csv = transaction.bonus or 0
                    total_tds_csv = transaction.transaction_tds or 0
                    no_of_days_present = transaction.stored_no_of_days_present if transaction.stored_no_of_days_present is not None else Attendance.get_no_of_present_days(employee, year, month)
                    paid_leaves = transaction.stored_paid_leaves if transaction.stored_paid_leaves is not None else LeaveRequest.get_total_paid_leaves(employee, year, month)
                    unpaid_leaves = transaction.stored_unpaid_leaves if transaction.stored_unpaid_leaves is not None else LeaveRequest.get_total_unpaid_leaves(employee, year, month)
                    half_leaves = transaction.stored_half_leaves if transaction.stored_half_leaves is not None else LeaveRequest.get_total_half_leaves(employee, year, month)
                else:
                    try:
                        net_salary = Salary.calculate_net_salary(employee=employee, year=year, month=month)
                    except Exception:
                        net_salary = salary.basic_salary or 0
                    incentive_csv = 0
                    bonus_csv = 0
                    total_tds_csv = round(((salary.basic_salary or 0) * (salary.tax_rate or 0)) / 100) if (salary.tax_rate or 0) > 0 else (salary.tds or 0)
                    try:
                        no_of_days_present = Attendance.get_no_of_present_days(employee, year, month)
                    except Exception:
                        no_of_days_present = 0
                    try:
                        paid_leaves = LeaveRequest.get_total_paid_leaves(employee, year, month)
                        unpaid_leaves = LeaveRequest.get_total_unpaid_leaves(employee, year, month)
                        half_leaves = LeaveRequest.get_total_half_leaves(employee, year, month)
                    except Exception:
                        paid_leaves, unpaid_leaves, half_leaves = 0, 0, 0

                writer.writerow([
                    str(user_obj.full_name or user_obj.username),
                    user_obj.email or '',
                    getattr(employee, 'pan_number', '') or '',
                    salary.basic_salary or 0,
                    salary.remote_salary or 0,
                    no_of_days_present,
                    paid_leaves,
                    unpaid_leaves,
                    half_leaves,
                    incentive_csv,
                    bonus_csv,
                    total_tds_csv,
                    net_salary
                ])

            return response
            
        else:
            return Response({'error': 'Either year/month or start_date/end_date query parameters are required.'}, status=status.HTTP_400_BAD_REQUEST)


# ──────────────────────────────────────────────────────────────
# Tax Band CRUD Views
# ──────────────────────────────────────────────────────────────

class SalaryTaxBandListCreateView(generics.ListCreateAPIView):
    serializer_class = SalaryTaxBandSerializer
    permission_classes = [IsAuthenticated, IsSalaryAdmin]
    nepali_date_filter_field = False

    def get_queryset(self):
        org = _get_org(self.request.user)
        if not org:
            return SalaryTaxBand.objects.none()
        marital = self.request.GET.get('marital_status')
        qs = SalaryTaxBand.objects.filter(organization=org)
        if marital:
            qs = qs.filter(marital_status=marital)
        return qs

    def perform_create(self, serializer):
        org = _get_org(self.request.user)
        serializer.save(organization=org)


class SalaryTaxBandDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = SalaryTaxBandSerializer
    permission_classes = [IsAuthenticated, IsSalaryAdmin]
    nepali_date_filter_field = False

    def get_queryset(self):
        org = _get_org(self.request.user)
        return SalaryTaxBand.objects.filter(organization=org) if org else SalaryTaxBand.objects.none()


class IncentiveTaxBandListCreateView(generics.ListCreateAPIView):
    serializer_class = IncentiveTaxBandSerializer
    permission_classes = [IsAuthenticated, IsSalaryAdmin]
    nepali_date_filter_field = False

    def get_queryset(self):
        org = _get_org(self.request.user)
        return IncentiveTaxBand.objects.filter(organization=org) if org else IncentiveTaxBand.objects.none()

    def perform_create(self, serializer):
        org = _get_org(self.request.user)
        serializer.save(organization=org)


class IncentiveTaxBandDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = IncentiveTaxBandSerializer
    permission_classes = [IsAuthenticated, IsSalaryAdmin]
    nepali_date_filter_field = False

    def get_queryset(self):
        org = _get_org(self.request.user)
        return IncentiveTaxBand.objects.filter(organization=org) if org else IncentiveTaxBand.objects.none()


class BonusTaxBandListCreateView(generics.ListCreateAPIView):
    serializer_class = BonusTaxBandSerializer
    permission_classes = [IsAuthenticated, IsSalaryAdmin]
    nepali_date_filter_field = False

    def get_queryset(self):
        org = _get_org(self.request.user)
        return BonusTaxBand.objects.filter(organization=org) if org else BonusTaxBand.objects.none()

    def perform_create(self, serializer):
        org = _get_org(self.request.user)
        serializer.save(organization=org)


class BonusTaxBandDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = BonusTaxBandSerializer
    permission_classes = [IsAuthenticated, IsSalaryAdmin]
    nepali_date_filter_field = False

    def get_queryset(self):
        org = _get_org(self.request.user)
        return BonusTaxBand.objects.filter(organization=org) if org else BonusTaxBand.objects.none()


# ──────────────────────────────────────────────────────────────
# Finance Account Management (Super Admin / Org Admin Only)
# ──────────────────────────────────────────────────────────────

class FinanceUserListCreateAPIView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated, IsStrictSalaryAdmin]
    serializer_class = FinanceAccessSerializer
    nepali_date_filter_field = False

    def get_queryset(self):
        org = _get_org(self.request.user)
        qs = FinanceAccess.objects.select_related('user', 'organization')
        return qs.filter(organization=org) if org else FinanceAccess.objects.none()

    def create(self, request, *args, **kwargs):
        org = _get_org(request.user)
        if not org:
            return Response(
                {'error': 'No organization found for this administrator.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer = FinanceAccessCreateSerializer(
            data=request.data, context={'request': request, 'organization': org}
        )
        serializer.is_valid(raise_exception=True)
        access = serializer.save()
        out = FinanceAccessSerializer(access, context={'request': request})
        return Response(out.data, status=status.HTTP_201_CREATED)


class FinanceUserDetailAPIView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated, IsStrictSalaryAdmin]
    serializer_class = FinanceAccessSerializer
    nepali_date_filter_field = False

    def get_queryset(self):
        org = _get_org(self.request.user)
        qs = FinanceAccess.objects.select_related('user', 'organization')
        return qs.filter(organization=org) if org else FinanceAccess.objects.none()

    def perform_destroy(self, instance):
        account = instance.user
        instance.delete()
        account.is_finance = False
        update_fields = ['is_finance']
        if not hasattr(account, 'employee') and not account.is_superuser:
            account.is_active = False
            update_fields.append('is_active')
        account.save(update_fields=update_fields)


# ──────────────────────────────────────────────────────────────
# Monthly & Yearly Financial Analytics Summary
# ──────────────────────────────────────────────────────────────

NEPALI_MONTH_NAMES = [
    '', 'Baishakh', 'Jestha', 'Ashadh', 'Shrawan',
    'Bhadra', 'Ashwin', 'Kartik', 'Mangsir',
    'Poush', 'Magh', 'Falgun', 'Chaitra',
]
NEPALI_MONTH_SHORT = [
    '', 'Bai', 'Jes', 'Ash', 'Shr',
    'Bha', 'Asw', 'Kar', 'Man',
    'Pou', 'Mag', 'Fal', 'Cha',
]


def _extract_tx_metrics(tx):
    """Compute consistent payroll numbers for a single SalaryTransaction."""
    sal = tx.salary
    gross = float(tx.gross_salary or 0) if sal else 0.0
    net = float(tx.net_salary or 0)
    incentive = float(tx.incentive or 0)
    bonus = float(tx.bonus or 0)

    if tx.transaction_tds is not None:
        tds = float(tx.transaction_tds)
    elif sal:
        tax_rate = float(sal.tax_rate or 0)
        tds = float(round((gross * tax_rate) / 100)) if tax_rate > 0 else float(sal.tds or 0)
    else:
        tds = 0.0

    ssf = float(tx.transaction_ssf) if tx.transaction_ssf is not None else float(sal.ssf or 0 if sal else 0)
    epf = float(tx.transaction_epf) if tx.transaction_epf is not None else float(sal.epf or 0 if sal else 0)
    cit = float(sal.citizen_investment_trust or 0) if sal else 0.0
    insurance = float(sal.insurance or 0) if sal else 0.0

    total_expense = (
        float(tx.total_expense)
        if tx.total_expense is not None
        else float(round(net + tds + ssf + epf + cit + insurance))
    )

    dept_name = 'Unassigned'
    designation_name = 'Unassigned'
    try:
        if sal and sal.employee and sal.employee.post:
            designation_name = sal.employee.post.title or 'Unassigned'
            if sal.employee.post.department:
                dept_name = sal.employee.post.department.department_name or 'Unassigned'
    except Exception:
        pass

    return {
        'gross': round(gross, 2),
        'net': round(net, 2),
        'tds': round(tds, 2),
        'ssf': round(ssf, 2),
        'epf': round(epf, 2),
        'cit': round(cit, 2),
        'insurance': round(insurance, 2),
        'incentive': round(incentive, 2),
        'bonus': round(bonus, 2),
        'total_expense': round(total_expense, 2),
        'department': dept_name,
        'designation': designation_name,
    }


class SalaryAnalyticsSummaryAPIView(APIView):
    """
    Returns organization-wide Monthly (12 BS months) and Yearly payroll
    analytics for Finance Charts (Expense, Net Paid, TDS, SSF, EPF,
    Deduction Breakdown, and Department Cost).
    """
    permission_classes = [IsAuthenticated, IsSalaryAdminOrHR]
    nepali_date_filter_field = False

    def get(self, request):
        org = _get_org(request.user)
        if not org:
            return Response({'error': 'No organization found.'}, status=status.HTTP_400_BAD_REQUEST)

        today_np = nepali_datetime.date.today()
        year_param = request.GET.get('year') or request.GET.get('nepali_year')
        month_param = request.GET.get('month') or request.GET.get('nepali_month')
        department_filter = request.GET.get('department')

        try:
            selected_year = int(year_param) if year_param else today_np.year
        except (TypeError, ValueError):
            selected_year = today_np.year

        selected_month = None
        if month_param and str(month_param).lower() not in ('all', 'none', ''):
            try:
                m_int = int(month_param)
                if 1 <= m_int <= 12:
                    selected_month = m_int
            except (TypeError, ValueError):
                selected_month = None

        qs = (
            SalaryTransaction.objects.filter(organization=org)
            .select_related('salary__employee__post__department', 'fiscal_year')
            .order_by('date')
        )

        # Initialize 12 BS month buckets for selected_year
        monthly_buckets = {
            m: {
                'month': m,
                'label': NEPALI_MONTH_NAMES[m],
                'short_label': NEPALI_MONTH_SHORT[m],
                'gross': 0.0,
                'net': 0.0,
                'tds': 0.0,
                'ssf': 0.0,
                'epf': 0.0,
                'cit': 0.0,
                'insurance': 0.0,
                'incentive': 0.0,
                'bonus': 0.0,
                'total_expense': 0.0,
                'payout_count': 0,
            }
            for m in range(1, 13)
        }
        yearly_buckets = {}
        available_years = {selected_year}

        # Breakdown + department accumulators (for selected_year, optionally narrowed to selected_month)
        breakdown = {
            'net': 0.0,
            'tds': 0.0,
            'ssf': 0.0,
            'epf': 0.0,
            'cit': 0.0,
            'insurance': 0.0,
            'incentive': 0.0,
            'bonus': 0.0,
        }
        dept_totals = {}
        designation_totals = {}
        kpis = {
            'total_expense': 0.0,
            'total_net': 0.0,
            'total_gross': 0.0,
            'total_tds': 0.0,
            'total_ssf': 0.0,
            'total_epf': 0.0,
            'total_bonus_incentive': 0.0,
            'payout_count': 0,
        }

        for tx in qs:
            if not tx.date:
                continue
            tx_year = tx.date.year
            tx_month = tx.date.month
            metrics = _extract_tx_metrics(tx)

            if department_filter and department_filter.lower() != 'all':
                if metrics['department'].lower() != department_filter.lower():
                    continue

            available_years.add(tx_year)

            # Yearly bucket
            if tx_year not in yearly_buckets:
                yearly_buckets[tx_year] = {
                    'year': tx_year,
                    'label': str(tx_year),
                    'gross': 0.0,
                    'net': 0.0,
                    'tds': 0.0,
                    'ssf': 0.0,
                    'epf': 0.0,
                    'incentive': 0.0,
                    'bonus': 0.0,
                    'total_expense': 0.0,
                    'payout_count': 0,
                }
            yb = yearly_buckets[tx_year]
            for key in ('gross', 'net', 'tds', 'ssf', 'epf', 'incentive', 'bonus', 'total_expense'):
                yb[key] += metrics[key]
            yb['payout_count'] += 1

            # Monthly bucket (for selected_year)
            if tx_year == selected_year and 1 <= tx_month <= 12:
                mb = monthly_buckets[tx_month]
                for key in ('gross', 'net', 'tds', 'ssf', 'epf', 'cit', 'insurance', 'incentive', 'bonus', 'total_expense'):
                    mb[key] += metrics[key]
                mb['payout_count'] += 1

                # KPIs + breakdown + department (filtered by selected_month if provided)
                if selected_month is None or tx_month == selected_month:
                    kpis['total_expense'] += metrics['total_expense']
                    kpis['total_net'] += metrics['net']
                    kpis['total_gross'] += metrics['gross']
                    kpis['total_tds'] += metrics['tds']
                    kpis['total_ssf'] += metrics['ssf']
                    kpis['total_epf'] += metrics['epf']
                    kpis['total_bonus_incentive'] += metrics['incentive'] + metrics['bonus']
                    kpis['payout_count'] += 1

                    for key in breakdown:
                        breakdown[key] += metrics[key]

                    dept = metrics['department']
                    if dept not in dept_totals:
                        dept_totals[dept] = {
                            'department': dept,
                            'total_expense': 0.0,
                            'net': 0.0,
                            'tds': 0.0,
                            'payout_count': 0,
                        }
                    dept_totals[dept]['total_expense'] += metrics['total_expense']
                    dept_totals[dept]['net'] += metrics['net']
                    dept_totals[dept]['tds'] += metrics['tds']
                    dept_totals[dept]['payout_count'] += 1

                    desig = metrics['designation']
                    if desig not in designation_totals:
                        designation_totals[desig] = {
                            'designation': desig,
                            'total_expense': 0.0,
                            'net': 0.0,
                            'tds': 0.0,
                            'payout_count': 0,
                        }
                    designation_totals[desig]['total_expense'] += metrics['total_expense']
                    designation_totals[desig]['net'] += metrics['net']
                    designation_totals[desig]['tds'] += metrics['tds']
                    designation_totals[desig]['payout_count'] += 1

        # Ensure selected_year appears in yearly array even if 0 payouts yet
        if selected_year not in yearly_buckets:
            yearly_buckets[selected_year] = {
                'year': selected_year,
                'label': str(selected_year),
                'gross': 0.0,
                'net': 0.0,
                'tds': 0.0,
                'ssf': 0.0,
                'epf': 0.0,
                'incentive': 0.0,
                'bonus': 0.0,
                'total_expense': 0.0,
                'payout_count': 0,
            }

        active_months = sum(1 for m in monthly_buckets.values() if m['payout_count'] > 0)
        kpis['avg_monthly_expense'] = round(
            kpis['total_expense'] / active_months, 2
        ) if (selected_month is None and active_months > 0) else round(kpis['total_expense'], 2)

        def _round_dict(d):
            return {k: (round(v, 2) if isinstance(v, float) else v) for k, v in d.items()}

        monthly_list = [_round_dict(monthly_buckets[m]) for m in range(1, 13)]
        yearly_list = [_round_dict(yearly_buckets[y]) for y in sorted(yearly_buckets.keys())]
        by_dept_list = sorted(
            [_round_dict(d) for d in dept_totals.values()],
            key=lambda x: x['total_expense'],
            reverse=True,
        )
        by_designation_list = sorted(
            [_round_dict(d) for d in designation_totals.values()],
            key=lambda x: x['total_expense'],
            reverse=True,
        )

        return Response({
            'selected_year': selected_year,
            'selected_month': selected_month,
            'available_years': sorted(available_years, reverse=True),
            'kpis': _round_dict(kpis),
            'monthly': monthly_list,
            'yearly': yearly_list,
            'deduction_breakdown': _round_dict(breakdown),
            'by_department': by_dept_list,
            'by_designation': by_designation_list,
        }, status=status.HTTP_200_OK)
