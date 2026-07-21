from datetime import timedelta
from django.db import models
from nepali_datetime import datetime
from nepali_datetime_field.models import NepaliDateField
from math import radians, sin, cos, sqrt, atan2

from organization.models import Employee, Organization, OrganizationAddress
from notification.models import Notification

# Create your models here.

from django.db import models


def format_timedelta(td):
    hours, remainder = divmod(td.seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    return f"{hours} hours {minutes} minutes"


class RemoteWorkPermission(models.Model):
    employee = models.OneToOneField(
        Employee, on_delete=models.CASCADE, null=True, related_name='remote_work_permission')
    is_allowed = models.BooleanField(default=False, null=True)
    remote_lat = models.FloatField(default=0)
    remote_lng = models.FloatField(default=0)

    def has_perm(self):
        """
        Checks if the remote user is within a 50-meter radius of the organization's primary location.

        Returns:
            bool: True if the user is within the 50-meter radius, False otherwise.
        """
        organization = self.employee.organization
        organization_location = OrganizationAddress.objects.filter(
            organization=organization, primary=True
        ).first()

        if not organization_location:
            return False

        EARTH_RADIUS = 6371000
        RADIUS_METERS = 50

        delta_lat = radians(organization_location.latitude - self.remote_lat)
        delta_lon = radians(organization_location.longitude - self.remote_lng)

        a = (
            sin(delta_lat / 2) ** 2
            + cos(radians(self.remote_lat)) *
            cos(radians(organization_location.latitude)) *
            sin(delta_lon / 2) ** 2
        )
        c = 2 * atan2(sqrt(a), sqrt(1 - a))

        distance = EARTH_RADIUS * c

        if distance <= RADIUS_METERS and self.is_allowed:
            return True
        else:
            return False


class CheckInOut(models.Model):
    attendance = models.ForeignKey(
        'Attendance', on_delete=models.CASCADE, related_name="check_ins_outs"
    )
    check_in = models.TimeField(null=True, blank=True)
    check_out = models.TimeField(null=True, blank=True)

    def __str__(self):
        return f"Check-in: {self.check_in}, Check-out: {self.check_out} for {self.attendance.date}"


class Attendance(models.Model):
    organization = models.ForeignKey(Organization, on_delete=models.CASCADE)
    employee = models.ForeignKey(
        Employee, on_delete=models.CASCADE, related_name="attendance"
    )
    date = NepaliDateField()
    is_remote = models.BooleanField(default=False, null=True, blank=True)
    check_in_lat = models.CharField(max_length=255, null=True, blank=True)
    check_in_lng = models.CharField(max_length=255, null=True, blank=True)
    check_out_lat = models.CharField(max_length=255, null=True, blank=True)
    check_out_lng = models.CharField(max_length=255, null=True, blank=True)

    def __str__(self):
        return f"Attendance on {self.date} for {self.employee}"

    @property
    def total_working_hours(self):
        total_seconds = sum(
            (
                datetime.combine(self.date, check_in_out.check_out)
                - datetime.combine(self.date, check_in_out.check_in)
            ).total_seconds()
            for check_in_out in self.check_ins_outs.all()
            if check_in_out.check_in and check_in_out.check_out
        )
        return (format_timedelta(timedelta(seconds=total_seconds)), total_seconds)

    def check_in_timestamp(self):
        first_check_in = self.check_ins_outs.all().order_by("id").first()
        return first_check_in.check_in

    def check_out_timestamp(self):
        last_check_out = self.check_ins_outs.all().order_by("id").last()
        if last_check_out:
            return last_check_out.check_out
        else:
            return None

    def has_checked_in(self) -> bool:
        """
        Returns True if employee has checked in
        """
        first_check_in = self.check_ins_outs.all().order_by("id").first()
        return bool(first_check_in and first_check_in.check_in)

    def working_hour(self):
        today = datetime.now().date()
        current_time = datetime.now().time()

        total_seconds = 0

        # Get all check-ins and check-outs for today
        check_ins = self.check_ins_outs.filter(
            check_in__isnull=False).order_by('check_in')

        check_outs = self.check_ins_outs.filter(
            check_out__isnull=False).order_by('check_out')

        # Calculate durations for each check-in and check-out pair
        for check_in, check_out in zip(check_ins, check_outs):
            total_seconds += (
                (datetime.combine(today, check_out.check_out) -
                 datetime.combine(today, check_in.check_in)).total_seconds()
            )

        # If there are check-ins without corresponding check-outs, add time till now
        if check_ins and (not check_outs or len(check_ins) > len(check_outs)):
            last_check_in = check_ins.last()
            if last_check_in.check_in and not last_check_in.check_out:
                total_seconds += (
                    (datetime.combine(today, current_time) -
                     datetime.combine(today, last_check_in.check_in)).total_seconds()
                )
        return timedelta(seconds=total_seconds)

    def formated_working_hour(self):
        # Assuming this method returns a timedelta
        working_hour = self.working_hour()
        if working_hour:
            total_seconds = int(working_hour.total_seconds())
            hours, remainder = divmod(total_seconds, 3600)
            minutes, seconds = divmod(remainder, 60)
            return f"{hours} Hrs {minutes} Mins"
        return "N/A"

    def get_recent_checkin(self):
        recent_check_in = (
            self.check_ins_outs.filter(
                check_in__isnull=False  # Ensure check_in is not null
            )
            .order_by("-check_in")
            .first()
        )
        return recent_check_in if recent_check_in else None

    @staticmethod
    def check_in(employee: Employee, lat: float, lng: float, within_radius: bool):
        """
        Handles the check-in process for an employee.

        Args:
            employee (Employee): The employee who is checking in.
            lat (float): The latitude of the check-in location.
            lng (float): The longitude of the check-in location.
            within_radius (bool): Indicates if the check-in is within the organization's allowed radius.

        Raises:
            ValueError: If the employee tries to check in again without checking out first.

        Returns:
            CheckInOut: The created CheckInOut instance representing the check-in.
        """
        organization: Organization = employee.organization
        admin_users = organization.admin_users.all()
        today = datetime.now().date()

        # Get or create today's attendance record for the employee
        attendance, created = Attendance.objects.get_or_create(
            organization=organization,
            employee=employee,
            date=today,
            defaults={
                'check_in_lat': lat,
                'check_in_lng': lng,
                'is_remote': not within_radius
            }
        )

        # Update check-in location details if the attendance record already exists
        if not created:
            attendance.check_in_lat = lat
            attendance.check_in_lng = lng
            attendance.is_remote = not within_radius
            attendance.save()

        # Ensure there are no open check-ins without a check-out
        if attendance.check_ins_outs.filter(check_out__isnull=True).exists():
            raise ValueError(
                "You cannot check in again without checking out first."
            )

        # Create a new check-in record
        check_in_out = CheckInOut.objects.create(
            attendance=attendance,
            check_in=datetime.now().time()
        )

        # Create and assign notifications
        notification = Notification.objects.create(
            user=employee.user,
            title=f'{employee} checked in',
            message=f'{employee} checked in at {check_in_out.check_in}'
        )

        for user in admin_users:
            notification = Notification.objects.create(
                user=user,
                title=f'{employee} checked in',
                message=f"{employee} checked in at {check_in_out.check_in}",
                is_read=False
            )

        return check_in_out

    @staticmethod
    def check_out(employee, lat, lng, within_radius):
        """
        Handles the check-out process for an employee.

        Args:
            employee (Employee): The employee who is checking out.
            lat (float): The latitude of the check-out location.
            lng (float): The longitude of the check-out location.
            within_radius (bool): Indicates if the check-out is within the organization's allowed radius.

        Raises:
            ValueError: If no attendance record exists for today or if there is no open check-in.

        Returns:
            CheckInOut: The updated CheckInOut instance representing the check-out.
        """
        organization: Organization = employee.organization
        admin_users = organization.admin_users.all()
        today = datetime.now().date()

        # Retrieve today's attendance for the employee
        attendance = Attendance.objects.filter(
            organization=employee.organization,
            employee=employee,
            date=today
        ).first()
        if not attendance:
            raise ValueError("No attendance record found for today.")

        # Update check-out location details
        attendance.check_out_lat = lat
        attendance.check_out_lng = lng
        attendance.is_remote = not within_radius
        attendance.save()

        # Find the open check-in record
        check_in_out = attendance.check_ins_outs.filter(
            check_out__isnull=True).first()
        if not check_in_out:
            raise ValueError("You must check in before checking out.")

        # Record the check-out time
        check_in_out.check_out = datetime.now().time()
        check_in_out.save()

        # Create and assign notifications
        notification = Notification.objects.create(
            user=employee.user,
            title=f'{employee} checked out',
            message=f'{employee} checked out at {check_in_out.check_in}',
            is_read=False,
        )

        for user in admin_users:
            notification = Notification.objects.create(
                user=user,
                title=f'{employee} checked out',
                message=f'{employee} checked out at {check_in_out.check_in}',
                is_read=False,
            )

        return check_in_out

    @staticmethod
    def has_checked_in_today(employee):
        # Get today's date
        today = datetime.now().date()

        # Check if an attendance record exists for today
        attendance = Attendance.objects.filter(
            employee=employee, date=today).first()

        if not attendance:
            return False
        # Check if there is a check-in today without a check-out
        has_open_check_in = attendance.check_ins_outs.filter(
            check_in__isnull=False, check_out__isnull=True).exists()
        return has_open_check_in

    @staticmethod
    def attendance_exists_today(employee):
        # Get today's date
        today = datetime.now().date()

        # Check if today's attendance exists for the given employee
        attendance_exists = Attendance.objects.filter(
            employee=employee, date=today).exists()

        return attendance_exists

    @staticmethod
    def check_in_time(employee):
        # Get today's date
        today = datetime.now().date()

        # Find today's attendance for the employee
        attendance = Attendance.objects.filter(
            employee=employee, date=today).first()

        if not attendance:
            return None

        # Query all check-ins for today
        recent_check_in = attendance.check_ins_outs.filter(
            check_in__isnull=False).order_by('-check_in').first()

        if recent_check_in:
            return recent_check_in
        return None  # No check-ins recorded today

    @staticmethod
    def most_recent_check_out(employee):
        # Get today's date
        today = datetime.now().date()

        # Find today's attendance for the employee
        attendance = Attendance.objects.filter(
            employee=employee, date=today).first()
        if not attendance:
            return None  # No attendance record for today

        # Query all check-outs for today
        recent_check_out = attendance.check_ins_outs.filter(
            check_out__isnull=False).order_by('-check_out').first()

        if recent_check_out:
            return recent_check_out.check_out

        return None  # No check-outs recorded today

    @staticmethod
    def total_working_hours_today(employee):
        today = datetime.now().date()
        current_time = datetime.now().time()

        # Find today's attendance for the employee
        attendance = Attendance.objects.filter(
            employee=employee, date=today).first()
        if not attendance:
            return None  # No attendance record for today

        total_seconds = 0

        # Get all check-ins and check-outs for today
        check_ins = attendance.check_ins_outs.filter(
            check_in__isnull=False).order_by('check_in')
        check_outs = attendance.check_ins_outs.filter(
            check_out__isnull=False).order_by('check_out')

        # Calculate durations for each check-in and check-out pair
        for check_in, check_out in zip(check_ins, check_outs):
            total_seconds += (
                (datetime.combine(today, check_out.check_out) -
                 datetime.combine(today, check_in.check_in)).total_seconds()
            )

        # If there are check-ins without corresponding check-outs, add time till now
        if check_ins and (not check_outs or len(check_ins) > len(check_outs)):
            last_check_in = check_ins.last()
            if last_check_in.check_in and not last_check_in.check_out:
                total_seconds += (
                    (datetime.combine(today, current_time) -
                     datetime.combine(today, last_check_in.check_in)).total_seconds()
                )

        return timedelta(seconds=total_seconds)

    @staticmethod
    def percentage_of_shift_covered(employee: Employee):
        organization: Organization = employee.organization

        shift_start = datetime.combine(
            datetime.now().date(), organization.opening_time)
        shift_end = datetime.combine(
            datetime.now().date(), organization.closing_time)
        total_shift_duration = (shift_end - shift_start).total_seconds()

        if total_shift_duration <= 0:
            return 0

        # Calculate total worked hours today
        worked_hours = Attendance.total_working_hours_today(employee)
        if worked_hours:
            worked_seconds = worked_hours.total_seconds()
            # Calculate percentage of shift covered
            percentage = (worked_seconds / total_shift_duration) * 100
            formatted_hours = f"{int(worked_hours.total_seconds() // 3600):02} Hrs : {int((worked_hours.total_seconds() % 3600) // 60):02} Mins"
        else:
            formatted_hours = "00 Hrs : 00 Mins"
            percentage = 0

        return formatted_hours, int(percentage)

    @staticmethod
    def get_attendance_of_selected_month(employee: Employee, year: int = None,  month: int = None):
        """
            Retrieves all attendance records for a given employee for the specified month and year.

            This static method filters the attendance records for the specified employee by 
            iterating through all attendance entries and selecting those that match the given 
            year and month. It then filters the `Attendance` model by the selected attendance IDs.

            Parameters:
            employee (Employee): The employee whose attendance is being retrieved.
            month (int, optional): The month (1-12) for which the attendance is requested. 
                                Defaults to None. If None, no filtering by month is done.
            year (int, optional): The year for which the attendance is requested. Defaults to None. 
                                If None, no filtering by year is done.

            Returns:
            QuerySet[Attendance]: A QuerySet of filtered attendance records for the specified 
                                month and year, ordered by date in ascending order.
        """
        attendance_list = Attendance.objects.filter(
            organization=employee.organization, employee=employee
        )
        filter_attendance_id_list = []

        for attendance in attendance_list:
            if (
                attendance.date.year == year
                and attendance.date.month == month
            ):
                # if attendance.has_checked_in_today:
                filter_attendance_id_list.append(attendance.id)

        return Attendance.objects.filter(id__in=filter_attendance_id_list).order_by('date')

    @staticmethod
    def get_no_of_present_days(employee: Employee, year: int = datetime.today(), month: int = datetime.today().month) -> int:
        total_attendance = Attendance.get_attendance_of_selected_month(
            employee=employee, year=year, month=month)
        no_of_present_days = []
        attendance_list = [
            attendance for attendance in total_attendance if attendance.has_checked_in()]

        return len(attendance_list)
