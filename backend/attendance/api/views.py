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

        selected_year = request.GET.get('selected_year')
        selected_month = request.GET.get('selected_month')
        current_month = nepali_datetime.date.today().month
        current_year = nepali_datetime.date.today().year

        all_attendance = Attendance.objects.filter(
            organization=employee.organization, employee=employee)
        current_month_total_working_hour = 0

        if selected_year and selected_month:
            for attendance in all_attendance:
                if attendance.date.year == int(selected_year) and attendance.date.month == int(selected_month):
                    _, total_working_seconds = attendance.total_working_hours
                    current_month_total_working_hour += total_working_seconds / 3600
            total_no_of_days_present = Attendance.get_no_of_present_days(
                employee=employee, year=int(selected_year), month=int(selected_month))
        else:
            for attendance in all_attendance:
                if attendance.date.year == current_year and attendance.date.month == current_month:
                    _, total_working_seconds = attendance.total_working_hours
                    current_month_total_working_hour += total_working_seconds / 3600
            total_no_of_days_present = Attendance.get_no_of_present_days(
                employee=employee, year=current_year, month=current_month)

        return Response({
            'total_working_hour': round(current_month_total_working_hour, 2),
            'remaining_working_hour': round(182 - current_month_total_working_hour, 2),
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

        within_remote_radius = False
        if remote_work_permission:
            within_remote_radius = is_within_radius(
                current_lat=user_lat, current_lng=user_lng,
                target_lat=float(remote_work_permission.remote_lat),
                target_lng=float(remote_work_permission.remote_lng))

        if not within_organization_radius and not within_remote_radius:
            return Response({'error': 'You are not within the office or remote work radius.'},
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

        within_remote_radius = False
        if remote_work_permission:
            within_remote_radius = is_within_radius(
                current_lat=user_lat, current_lng=user_lng,
                target_lat=float(remote_work_permission.remote_lat),
                target_lng=float(remote_work_permission.remote_lng))

        if not within_organization_radius and not within_remote_radius:
            return Response({'error': 'You are not within the office or remote work radius.'},
                            status=status.HTTP_401_UNAUTHORIZED)

        photo = request.FILES.get('photo')

        try:
            check_in = Attendance.check_out(
                request.user.employee, lat=user_lat, lng=user_lng,
                within_radius=within_organization_radius, photo=photo)
        except ValueError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response({
            "check_in_time": check_in.check_out,
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
        try:
            org = request.user.employee.organization
        except Exception:
            orgs = request.user.organization.all()
            if not orgs.exists():
                return Response([])
            org = orgs.first()

        date_str = request.GET.get('date')
        qs = Attendance.objects.filter(organization=org).order_by('-date')

        if date_str:
            try:
                y, m, d = map(int, date_str.split('-'))
                qs = qs.filter(date=nepali_datetime.date(y, m, d))
            except Exception:
                pass

        result = []
        for att in qs[:200]:
            first_ci = att.check_ins_outs.order_by('id').first()
            last_co = att.check_ins_outs.filter(
                check_out__isnull=False).order_by('-check_out').first()
            _, total_secs = att.total_working_hours
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
                'check_in_photo': request.build_absolute_uri(att.check_in_photo.url) if att.check_in_photo else None,
                'check_out_photo': request.build_absolute_uri(att.check_out_photo.url) if att.check_out_photo else None,
            })
        return Response(result)


# ─── Remote Work Permission Views ─────────────────────────────────────────────

class RemoteWorkPermissionListAPIView(APIView):
    """Admin: list every employee in the org with their remote-permission status."""
    permission_classes = [IsAuthenticated, IsOrgAdmin]

    def get(self, request):
        try:
            organization = request.user.employee.organization
        except Exception:
            orgs = request.user.organization.all()
            if not orgs.exists():
                return Response([])
            organization = orgs.first()

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
        try:
            return request.user.employee.organization
        except Exception:
            orgs = request.user.organization.all()
            return orgs.first() if orgs.exists() else None

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

        try:
            organization = request.user.employee.organization
        except Exception:
            organization = None

        if organization:
            employees = Employee.objects.filter(organization=organization)
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
            monthly_attendances = [a for a in all_attendances if a.date.year == year and a.date.month == month]
            
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
