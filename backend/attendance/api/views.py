import nepali_datetime
from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, BasePermission

from attendance.models import Attendance, CheckInOut, RemoteWorkPermission
from attendance.utils import is_within_radius
from organization.models import Employee, OrganizationAddress
from .serializers import AttendanceSerializer, RemoteWorkPermissionSerializer


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
                target_lat=remote_work_permission.remote_lat,
                target_lng=remote_work_permission.remote_lng)

        if not within_organization_radius and not within_remote_radius:
            return Response({'error': 'You are not within the office or remote work radius.'},
                            status=status.HTTP_401_UNAUTHORIZED)

        check_in = Attendance.check_in(
            request.user.employee, lat=user_lat, lng=user_lng,
            within_radius=within_organization_radius)

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
                target_lat=remote_work_permission.remote_lat,
                target_lng=remote_work_permission.remote_lng)

        if not within_organization_radius and not within_remote_radius:
            return Response({'error': 'You are not within the office or remote work radius.'},
                            status=status.HTTP_401_UNAUTHORIZED)

        try:
            check_in = Attendance.check_out(
                request.user.employee, lat=user_lat, lng=user_lng,
                within_radius=within_organization_radius)
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
