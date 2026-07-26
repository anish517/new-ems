import nepali_datetime
from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, BasePermission
from django.http import HttpResponse
import csv

from attendance.models import Attendance, CheckInOut, RemoteWorkPermission
from attendance.utils import is_within_radius
from organization.models import Employee, OrganizationAddress
from .serializers import AttendanceSerializer, RemoteWorkPermissionSerializer
from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import TokenError, InvalidToken
from django.contrib.auth import get_user_model


class IsOrgAdmin(BasePermission):
    """Allows access only to org admins (users whose employee.canManage is true)."""
    def has_permission(self, request, view):
        try:
            # Super admins (linked via organization FK) are also admins
            return bool(request.user.organization.exists() or request.user.is_superuser)
        except Exception:
            return False


class AttendanceDetailAPIView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    queryset = Attendance.objects.all()
    serializer_class = AttendanceSerializer


class RetrieveTotalWorkingHourAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, employee_id, format=None):
        try:
            employee = Employee.objects.get(id=employee_id)
        except Employee.DoesNotExist:
            return Response({'message': 'Employee not found'}, status=status.HTTP_404_NOT_FOUND)

        selected_year = request.GET.get('nepali_year') or request.GET.get('selected_year')
        selected_month = request.GET.get('nepali_month') or request.GET.get('selected_month')
        current_month = nepali_datetime.date.today().month
        current_year = nepali_datetime.date.today().year

        y = int(selected_year) if selected_year else current_year
        m = int(selected_month) if selected_month else current_month

        all_attendance = Attendance.objects.filter(
            organization=employee.organization, 
            employee=employee
        ).prefetch_related('check_ins_outs')

        monthly_attendance = [a for a in all_attendance if getattr(a.date, 'year', None) == y and getattr(a.date, 'month', None) == m]

        current_month_total_working_hour = 0
        for attendance in monthly_attendance:
            _, total_working_seconds = attendance.total_working_hours
            current_month_total_working_hour += total_working_seconds / 3600
            
        total_no_of_days_present = Attendance.get_no_of_present_days(
            employee=employee, year=y, month=m)

        # Calculate expected monthly working hours dynamically from org shift
        try:
            import datetime as _dt
            import nepali_datetime as _ndt
            org = employee.organization
            if org.opening_time and org.closing_time:
                open_dt = _dt.datetime.combine(_dt.date.today(), org.opening_time)
                close_dt = _dt.datetime.combine(_dt.date.today(), org.closing_time)
                shift_hours = (close_dt - open_dt).total_seconds() / 3600
            else:
                shift_hours = 8.0  # default 8-hour day

            # Count working days (Mon–Sat) in the Nepali month, excluding Sundays
            # In Nepal, Sunday (weekday=6 in Python's isoweekday: Mon=1..Sun=7) is the weekly off
            from calendar_app.utilities import total_days_in_month as nepali_total_days
            selected_y = int(selected_year) if selected_year else current_year
            selected_m = int(selected_month) if selected_month else current_month
            days_in_month = nepali_total_days(year=selected_y, month=selected_m)

            # Count Sundays in the selected Nepali month
            working_days = 0
            for day in range(1, days_in_month + 1):
                try:
                    nep_date = _ndt.date(selected_y, selected_m, day)
                    # Convert to Python date to get weekday; isoweekday() Sun=7
                    py_date = nep_date.to_datetime_date()
                    if py_date.isoweekday() != 7:  # 7 = Sunday
                        working_days += 1
                except Exception:
                    pass

            expected_monthly_hours = round(shift_hours * working_days, 2)
        except Exception:
            expected_monthly_hours = 182  # safe fallback

        return Response({
            'total_working_hour': round(current_month_total_working_hour, 2),
            'remaining_working_hour': round(expected_monthly_hours - current_month_total_working_hour, 2),
            'total_no_of_days_present': total_no_of_days_present,
        }, status=status.HTTP_200_OK)


class EmployeeAttendanceAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, employee_id, format=None):
        try:
            employee = Employee.objects.get(id=employee_id)
        except Employee.DoesNotExist:
            return Response({'message': 'Employee not found'}, status=status.HTTP_404_NOT_FOUND)

        current_year = nepali_datetime.date.today().year
        yearly_attendance_history = [0] * 12

        for attendance in Attendance.objects.filter(employee=employee):
            if attendance.date.year == current_year and attendance.has_checked_in():
                yearly_attendance_history[attendance.date.month - 1] += 1

        total_days_in_year = sum(yearly_attendance_history)
        working_days_in_year = nepali_datetime.date.today().timetuple().tm_yday
        shift_completion_percentage = (
            total_days_in_year / working_days_in_year) * 100 if working_days_in_year else 0

        return Response({
            'id': employee.id,
            'first_name': employee.user.first_name,
            'last_name': employee.user.last_name,
            'email': employee.user.email,
            'percentage_shift_completion': round(shift_completion_percentage, 2),
            'yearly_attendance_history': yearly_attendance_history,
        }, status=status.HTTP_200_OK)


class CheckIn(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user_lat = request.data.get("latitude")
        user_lng = request.data.get("longitude")

        if user_lat is None or user_lng is None:
            return Response({"error": "Latitude and longitude are required."},
                            status=status.HTTP_400_BAD_REQUEST)

        try:
            user_lat = float(user_lat)
            user_lng = float(user_lng)
        except (ValueError, TypeError):
            return Response({"error": "Latitude and longitude must be valid numbers."},
                            status=status.HTTP_400_BAD_REQUEST)

        try:
            organization = request.user.employee.organization
        except Exception:
            return Response({"error": "No employee profile linked to this account."},
                            status=status.HTTP_400_BAD_REQUEST)

        organization_address = OrganizationAddress.objects.filter(
            organization=organization, primary=True).first()
        if organization_address is None:
            return Response({"error": "Organization address not configured."},
                            status=status.HTTP_400_BAD_REQUEST)

        try:
            remote_work_permission = request.user.employee.remote_work_permission
            if not remote_work_permission.is_allowed:
                remote_work_permission = None
        except Exception:
            remote_work_permission = None

        within_organization_radius = is_within_radius(
            current_lat=user_lat, current_lng=user_lng,
            target_lat=organization_address.latitude,
            target_lng=organization_address.longitude)

        # Remote-permitted employees can check in from anywhere worldwide
        has_remote_permission = remote_work_permission is not None  # is_allowed already verified above

        if not within_organization_radius and not has_remote_permission:
            return Response({'error': 'You are not within the office radius. Contact your admin to enable remote work.'},
                            status=status.HTTP_401_UNAUTHORIZED)

        photo = request.FILES.get('photo')

        check_in = Attendance.check_in(
            request.user.employee, lat=user_lat, lng=user_lng,
            within_radius=within_organization_radius, photo=photo)

        return Response({
            "check_in_time": check_in.check_in,
            "is_remote": check_in.attendance.is_remote,
        })


class CheckOut(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user_lat = request.data.get("latitude")
        user_lng = request.data.get("longitude")

        if user_lat is None or user_lng is None:
            return Response({"error": "Latitude and longitude are required."},
                            status=status.HTTP_400_BAD_REQUEST)

        try:
            user_lat = float(user_lat)
            user_lng = float(user_lng)
        except (ValueError, TypeError):
            return Response({"error": "Latitude and longitude must be valid numbers."},
                            status=status.HTTP_400_BAD_REQUEST)

        try:
            organization = request.user.employee.organization
        except Exception:
            return Response({"error": "No employee profile linked to this account."},
                            status=status.HTTP_400_BAD_REQUEST)

        organization_address = OrganizationAddress.objects.filter(
            organization=organization, primary=True).first()
        if organization_address is None:
            return Response({"error": "Organization address not configured."},
                            status=status.HTTP_400_BAD_REQUEST)

        try:
            remote_work_permission = request.user.employee.remote_work_permission
            if not remote_work_permission.is_allowed:
                remote_work_permission = None
        except Exception:
            remote_work_permission = None

        within_organization_radius = is_within_radius(
            current_lat=user_lat, current_lng=user_lng,
            target_lat=organization_address.latitude,
            target_lng=organization_address.longitude)

        # Remote-permitted employees can check out from anywhere worldwide
        has_remote_permission = remote_work_permission is not None  # is_allowed already verified above

        if not within_organization_radius and not has_remote_permission:
            return Response({'error': 'You are not within the office radius. Contact your admin to enable remote work.'},
                            status=status.HTTP_401_UNAUTHORIZED)

        photo = request.FILES.get('photo')

        try:
            check_in = Attendance.check_out(
                request.user.employee, lat=user_lat, lng=user_lng,
                within_radius=within_organization_radius, photo=photo)
        except ValueError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response({
            "check_out_time": check_in.check_out,
            "is_remote": check_in.attendance.is_remote,
        })


class TodayAttendanceStatusAPIView(APIView):
    """Returns today's check-in status for the current employee."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            employee = request.user.employee
        except Exception:
            return Response({'is_checked_in': False, 'check_in_time': None})

        today = nepali_datetime.date.today()
        attendance = Attendance.objects.filter(employee=employee, date=today).first()
        if not attendance:
            return Response({'is_checked_in': False, 'check_in_time': None})

        open_checkin = attendance.check_ins_outs.filter(check_out__isnull=True).first()
        first_checkin = attendance.check_ins_outs.order_by('id').first()
        return Response({
            'is_checked_in': open_checkin is not None,
            'check_in_time': str(first_checkin.check_in) if first_checkin and first_checkin.check_in else None,
        })


class AttendanceListAPIView(APIView):
    """Returns all attendance records for the organization."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        org = getattr(user.employee, 'organization', None) if hasattr(user, 'employee') else None
        if not org:
            if user.organization.exists():
                org = user.organization.first()
            elif getattr(user, 'is_superuser', False) or getattr(user, 'is_hr', False):
                from organization.models import Organization
                org = Organization.objects.first()
                
        if not org:
            return Response([])

        date_str = request.GET.get('date')
        employee_id = request.GET.get('employee')
        
        qs = Attendance.objects.filter(organization=org).select_related(
            'employee', 'employee__user'
        ).prefetch_related('check_ins_outs').order_by('-date')

        if employee_id:
            qs = qs.filter(employee_id=employee_id)

        if date_str:
            try:
                y, m, d = map(int, date_str.split('-'))
                qs = qs.filter(date=nepali_datetime.date(y, m, d))
            except Exception:
                pass
                
        ny = request.GET.get('nepali_year')
        nm = request.GET.get('nepali_month')
        if ny and nm:
            try:
                y = int(ny)
                m = int(nm)
                from calendar_app.utilities import total_days_in_month
                import nepali_datetime
                days = total_days_in_month(y, m)
                start_date = nepali_datetime.date(y, m, 1)
                end_date = nepali_datetime.date(y, m, days)
                qs = qs.filter(date__gte=start_date, date__lte=end_date)
            except Exception:
                pass

        from rest_framework.pagination import PageNumberPagination
        paginator = PageNumberPagination()
        paginator.page_size = 50
        paginated_qs = paginator.paginate_queryset(qs, request)

        result = []
        for att in paginated_qs:
            checkins = list(att.check_ins_outs.all())
            checkins_sorted = sorted(checkins, key=lambda x: x.id)
            
            first_ci = checkins_sorted[0] if checkins_sorted else None
            
            last_co = None
            for ci in reversed(checkins_sorted):
                if ci.check_out:
                    last_co = ci
                    break
            
            _, total_secs = att.total_working_hours
            history = []
            for ci_out in checkins_sorted:
                history.append({
                    'in': str(ci_out.check_in) if ci_out.check_in else None,
                    'out': str(ci_out.check_out) if ci_out.check_out else None,
                })
                
            result.append({
                'id': att.id,
                'employee_id': att.employee.id,
                'employee_name': att.employee.user.full_name if att.employee and att.employee.user else '',
                'date': str(att.date),
                'is_remote': att.is_remote,
                'check_in_time': str(first_ci.check_in) if first_ci and first_ci.check_in else None,
                'check_out_time': str(last_co.check_out) if last_co and last_co.check_out else None,
                'total_hours': round(total_secs / 3600, 2),
                'check_in_lat': str(att.check_in_lat) if att.check_in_lat else None,
                'check_in_lng': str(att.check_in_lng) if att.check_in_lng else None,
                'check_out_lat': str(att.check_out_lat) if att.check_out_lat else None,
                'check_out_lng': str(att.check_out_lng) if att.check_out_lng else None,
                'check_in_photo': request.build_absolute_uri(att.check_in_photo.url) if att.check_in_photo else None,
                'check_out_photo': request.build_absolute_uri(att.check_out_photo.url) if att.check_out_photo else None,
                'history': history,
            })
        
        return paginator.get_paginated_response(result)


# ─── Remote Work Permission Views ─────────────────────────────────────────────

class RemoteWorkPermissionListAPIView(APIView):
    """Admin: list every employee in the org with their remote-permission status."""
    permission_classes = [IsAuthenticated, IsOrgAdmin]

    def get(self, request):
        user = request.user
        organization = getattr(user.employee, 'organization', None) if hasattr(user, 'employee') else None
        if not organization:
            if user.organization.exists():
                organization = user.organization.first()
            elif getattr(user, 'is_superuser', False) or getattr(user, 'is_hr', False):
                from organization.models import Organization
                organization = Organization.objects.first()
                
        if not organization:
            return Response([])

        employees = Employee.objects.filter(post__department__organization=organization)
        result = []
        for emp in employees:
            perm = getattr(emp, 'remote_work_permission', None)
            has_perm = perm is not None and perm.is_allowed
            result.append({
                'employee_id': emp.id,
                'employee_name': emp.user.full_name if emp.user else '',
                'has_remote_permission': has_perm,
                'remote_lat': perm.remote_lat if has_perm else None,
                'remote_lng': perm.remote_lng if has_perm else None,
            })
        return Response(result)


class AdminSetRemoteWorkPermissionAPIView(APIView):
    """Admin: create/update or remove one employee's approved remote spot."""
    permission_classes = [IsAuthenticated, IsOrgAdmin]

    def _get_org(self, request):
        user = request.user
        org = getattr(user.employee, 'organization', None) if hasattr(user, 'employee') else None
        if not org:
            if user.organization.exists():
                org = user.organization.first()
            elif getattr(user, 'is_superuser', False) or getattr(user, 'is_hr', False):
                from organization.models import Organization
                org = Organization.objects.first()
        return org

    def post(self, request, employee_id):
        org = self._get_org(request)
        try:
            employee = Employee.objects.get(id=employee_id, post__department__organization=org)
        except Employee.DoesNotExist:
            return Response({'error': 'Employee not found'}, status=status.HTTP_404_NOT_FOUND)

        lat = request.data.get('latitude')
        lng = request.data.get('longitude')
        if lat is None or lng is None:
            return Response({'error': 'Latitude and longitude are required.'},
                            status=status.HTTP_400_BAD_REQUEST)

        perm, _ = RemoteWorkPermission.objects.get_or_create(employee=employee)
        perm.remote_lat = lat
        perm.remote_lng = lng
        perm.is_allowed = True
        perm.save()
        return Response(RemoteWorkPermissionSerializer(perm).data)

    def delete(self, request, employee_id):
        org = self._get_org(request)
        try:
            employee = Employee.objects.get(id=employee_id, post__department__organization=org)
        except Employee.DoesNotExist:
            return Response({'error': 'Employee not found'}, status=status.HTTP_404_NOT_FOUND)

        RemoteWorkPermission.objects.filter(employee=employee).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

class MyRemoteWorkPermissionAPIView(APIView):
    """Employee: check their own remote-approval status (read-only)."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            perm = request.user.employee.remote_work_permission
            has_perm = perm is not None and perm.is_allowed
        except Exception:
            perm = None
            has_perm = False
        return Response({
            'has_remote_permission': has_perm,
            'remote_lat': perm.remote_lat if has_perm else None,
            'remote_lng': perm.remote_lng if has_perm else None,
        })


class GenerateAttendanceReportAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not (request.user.is_superuser or getattr(request.user, 'is_hr', False) or (hasattr(request.user, 'employee') and request.user.employee.organization.admin_users.filter(id=request.user.id).exists())):
            return Response({'error': 'You do not have permission to generate this report.'}, status=status.HTTP_403_FORBIDDEN)

        year_str = request.GET.get('year')
        month_str = request.GET.get('month')
        if not year_str or not month_str:
            return Response({'error': 'Year and month query parameters are required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            year = int(year_str)
            month = int(month_str)
        except ValueError:
            return Response({'error': 'Year and month must be valid integers.'}, status=status.HTTP_400_BAD_REQUEST)

        user = request.user
        organization = getattr(user.employee, 'organization', None) if hasattr(user, 'employee') else None
        if not organization:
            if user.organization.exists():
                organization = user.organization.first()
            elif getattr(user, 'is_superuser', False) or getattr(user, 'is_hr', False):
                from organization.models import Organization
                organization = Organization.objects.first()

        if organization:
            employees = Employee.objects.filter(post__department__organization=organization)
        else:
            employees = Employee.objects.all()

        import csv
        from django.http import HttpResponse
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="attendance_report_{year}_{month}.csv"'

        writer = csv.writer(response)
        writer.writerow(['Employee Name', 'Email', 'Total Present (Month)', 'Paid Leaves (Month)', 'Unpaid Leaves (Month)', 'Half Leaves (Month)', 'Total Working Hours (Month)'])

        from leave_management.models import LeaveRequest

        for employee in employees:
            present = Attendance.get_no_of_present_days(employee, year, month)
            paid_leaves = LeaveRequest.get_total_paid_leaves(employee, year, month)
            unpaid_leaves = LeaveRequest.get_total_unpaid_leaves(employee, year, month)
            half_leaves = LeaveRequest.get_total_half_leaves(employee, year, month)
            
            # Calculate total working hours in the month
            all_attendances = Attendance.objects.filter(employee=employee)
            monthly_attendances = [a for a in all_attendances if getattr(a.date, 'year', None) == year and getattr(a.date, 'month', None) == month]
            
            total_sec = sum(a.total_working_hours[1] for a in monthly_attendances)
            h = int(total_sec // 3600)
            m = int((total_sec % 3600) // 60)
            
            writer.writerow([
                str(employee),
                employee.user.email,
                present,
                paid_leaves,
                unpaid_leaves,
                half_leaves,
                f'{h}h {m}m'
            ])

        return response
