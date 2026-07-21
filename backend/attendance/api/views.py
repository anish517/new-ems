import nepali_datetime
from math import radians, sin, cos, sqrt, atan2
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator

from attendance.models import Attendance, CheckInOut, RemoteWorkPermission
import nepali_datetime.data
from attendance.utils import is_within_radius
from organization.models import Employee, OrganizationAddress
from .serializers import AttendanceSerializer, RemoteWorkPermissionSerializer


class AttendanceDetailAPIView(generics.RetrieveAPIView):
    permission_classes = [IsAuthenticated]

    queryset = Attendance.objects.all()
    serializer_class = AttendanceSerializer


class RetrieveTotalWorkingHourAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, employee_id, format=None):
        try:
            employee = Employee.objects.get(id=employee_id)
        except:
            employee = None
            return Response({'message': 'Employee not found'}, status=status.HTTP_404_NOT_FOUND)

        selected_year = request.GET.get('selected_year')
        selected_month = request.GET.get('selected_month')
        current_month = nepali_datetime.date.today().month
        current_year = nepali_datetime.date.today().year
        # total working hour
        all_attendance = Attendance.objects.filter(
            organization=employee.organization, employee=employee)
        current_month_total_working_hour = 0

        if selected_year and selected_month:
            for attendance in all_attendance:
                if attendance.date.year == int(selected_year) and attendance.date.month == int(selected_month):
                    formated_time, total_working_seconds = attendance.total_working_hours
                    one_day_working_hour = total_working_seconds/3600
                    current_month_total_working_hour += one_day_working_hour
            total_no_of_days_present = Attendance.get_no_of_present_days(
                employee=employee, year=int(selected_year), month=int(selected_month))

        else:
            for attendance in all_attendance:
                if attendance.date.year == current_year and attendance.date.month == current_month:
                    formated_time, total_working_seconds = attendance.total_working_hours
                    one_day_working_hour = total_working_seconds/3600
                    current_month_total_working_hour += one_day_working_hour
            total_no_of_days_present = Attendance.get_no_of_present_days(
                employee=employee, year=current_year, month=current_month)

        data = {
            'total_working_hour': round(current_month_total_working_hour, 2),
            'remaining_working_hour': 182 - round(current_month_total_working_hour, 2),
            'total_no_of_days_present': total_no_of_days_present
        }
        return Response(data=data, status=status.HTTP_200_OK)


class EmployeeAttendanceAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, employee_id, format=None):
        try:
            employee = Employee.objects.get(id=employee_id)
        except Employee.DoesNotExist:
            return Response({'message': 'Employee not found'}, status=status.HTTP_404_NOT_FOUND)

        # Fetch the current year and initialize attendance history for 12 months
        current_year = nepali_datetime.date.today().year
        yearly_attendance_history = [0] * 12

        # Get all attendance for the employee in the current year
        all_attendance = Attendance.objects.filter(
            employee=employee)

        current_year_attendance = []
        for attendance in all_attendance:
            if attendance.date.year == current_year:
                current_year_attendance.append(attendance)

        for attendance in current_year_attendance:
            if attendance.has_checked_in():  # If the employee was present for that day
                # Increment the count for the respective month
                yearly_attendance_history[attendance.date.month - 1] += 1

        # Calculate shift completion percentage
        total_days_in_year = sum(yearly_attendance_history)
        working_days_in_year = nepali_datetime.date.today(
        ).timetuple().tm_yday  # Days up to today
        shift_completion_percentage = (
            total_days_in_year / working_days_in_year) * 100

        # Prepare the response data
        data = {
            'id': employee.id,
            'first_name': employee.user.first_name,
            'last_name': employee.user.last_name,
            'email': employee.user.email,
            'percentage_shift_completion': round(shift_completion_percentage, 2),
            'yearly_attendance_history': yearly_attendance_history,
        }
        return Response(data=data, status=status.HTTP_200_OK)


class AttendanceCheckIn(APIView):
    TARGET_LAT = 27.683790760290307
    TARGET_LNG = 85.33621860988507
    RADIUS_METERS = 500


class CheckIn(APIView):

    def post(self, request):
        user_lat = request.data.get("latitude")
        user_lng = request.data.get("longitude")
        try:
            organization = self.request.user.employee.organization
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
        except Exception:
            remote_work_permission = None

        if user_lat is None or user_lng is None:
            return Response({"error": "Latitude and longitude are required."}, status=status.HTTP_400_BAD_REQUEST)

        within_organization_radius = is_within_radius(current_lat=user_lat, current_lng=user_lng,
                                                      target_lat=organization_address.latitude, target_lng=organization_address.longitude)

        if remote_work_permission:
            within_remote_radius = is_within_radius(
                current_lat=user_lat, current_lng=user_lng,
                target_lat=remote_work_permission.remote_lat,
                target_lng=remote_work_permission.remote_lng)
        else:
            within_remote_radius = False

        if not within_organization_radius and not within_remote_radius:
            return Response({'error': 'You are not within the office or remote work radius.'},
                            status=status.HTTP_401_UNAUTHORIZED)
        elif not within_organization_radius and within_remote_radius:
            check_in = Attendance.check_in(
                request.user.employee, lat=user_lat, lng=user_lng, within_radius=False)
        else:
            check_in = Attendance.check_in(
                request.user.employee, lat=user_lat, lng=user_lng, within_radius=True)

        return Response({
            "check_in_time": check_in.check_in,
            "is_remote": check_in.attendance.is_remote,
        })



class CheckOut(APIView):
    def post(self, request):
        user_lat = request.data.get("latitude")
        user_lng = request.data.get("longitude")
        organization = self.request.user.employee.organization
        organization_address = OrganizationAddress.objects.filter(
            organization=organization, primary=True).first()

        if user_lat is None or user_lng is None:
            return Response({"error": "Latitude and longitude are required."}, status=status.HTTP_400_BAD_REQUEST)

        within_office_radius = is_within_radius(current_lat=user_lat, current_lng=user_lng,
                                                target_lat=organization_address.latitude, target_lng=organization_address.longitude)

        try:
            check_in = Attendance.check_out(
                request.user.employee, lat=user_lat, lng=user_lng, within_radius=within_office_radius)
        except ValueError as e:
            print(e)
            return Response({'error': "Server error"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        return Response({
            "check_in_time": check_in.check_out,
            "is_remote": check_in.attendance.is_remote,
        })


class RemoteWorkPermissionRetrieveUpdateAPIView(generics.RetrieveUpdateAPIView):
    model = RemoteWorkPermission
    queryset = RemoteWorkPermission.objects.all()
    serializer_class = RemoteWorkPermissionSerializer
    permission_classes = [IsAuthenticated]


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
    """Returns all attendance records for the organization (admin use)."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Determine org
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
        for att in qs[:200]:  # cap at 200
            first_ci = att.check_ins_outs.order_by('id').first()
            last_co = att.check_ins_outs.filter(check_out__isnull=False).order_by('-check_out').first()
            _, total_secs = att.total_working_hours
            hours = round(total_secs / 3600, 2)
            result.append({
                'id': att.id,
                'employee_id': att.employee.id,
                'employee_name': att.employee.user.full_name if att.employee and att.employee.user else '',
                'date': str(att.date),
                'is_remote': att.is_remote,
                'check_in_time': str(first_ci.check_in) if first_ci and first_ci.check_in else None,
                'check_out_time': str(last_co.check_out) if last_co and last_co.check_out else None,
                'total_hours': hours,
            })
        return Response(result)
