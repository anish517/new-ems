from django.test import TestCase
from datetime import time
from nepali_datetime import date as nepali_date
from authentication.models import Account
from organization.models import Organization, Department, Post, Employee
from attendance.models import Attendance, CheckInOut, RemoteWorkPermission

class AttendanceTests(TestCase):
    def setUp(self):
        # Create hierarchy
        self.org = Organization.objects.create(name="Test Org")
        self.dept = Department.objects.create(organization=self.org, department_name="Engineering")
        self.post = Post.objects.create(department=self.dept, title="Developer")
        
        # Create Employee
        self.user = Account.objects.create(email="user@test.com", first_name="Test", last_name="User")
        self.emp = Employee.objects.create(user=self.user, post=self.post)

    def test_check_in_and_check_out_creation(self):
        """
        Test that attendance and its check-in/out records can be created successfully,
        and total working hours are calculated correctly.
        """
        attendance = Attendance.objects.create(
            organization=self.org,
            employee=self.emp,
            date=nepali_date(2080, 1, 1),
            is_remote=False
        )
        
        # Add a check-in at 9:00 AM and check-out at 5:00 PM
        CheckInOut.objects.create(
            attendance=attendance,
            check_in=time(9, 0),
            check_out=time(17, 0)
        )
        
        self.assertTrue(attendance.has_checked_in())
        self.assertIsNotNone(attendance.check_out_timestamp())
        
        # 9 AM to 5 PM = 8 hours = 28800 seconds
        formatted_time, total_seconds = attendance.total_working_hours
        self.assertEqual(total_seconds, 28800)
        self.assertIn("8 hours", formatted_time)

    def test_remote_work_permission_geofence(self):
        """
        Test the geofence validation for remote work (50m radius).
        """
        # Central coordinates (e.g. Kathmandu)
        base_lat = 27.7172
        base_lng = 85.3240
        
        # Update the auto-created RemoteWorkPermission object
        RemoteWorkPermission.objects.filter(employee=self.emp).update(
            is_allowed=True,
            remote_lat=base_lat,
            remote_lng=base_lng
        )
        remote_perm = RemoteWorkPermission.objects.get(employee=self.emp)
        
        # Exact same location should return True
        self.assertTrue(remote_perm.has_perm(base_lat, base_lng))
        
        # A location roughly ~10 meters away (approx 0.0001 degrees)
        self.assertTrue(remote_perm.has_perm(base_lat + 0.00005, base_lng + 0.00005))
        
        # A location ~1 km away (approx 0.01 degrees) should fail
        self.assertFalse(remote_perm.has_perm(base_lat + 0.01, base_lng))
        
        # If is_allowed is False, even the exact location should fail
        remote_perm.is_allowed = False
        remote_perm.save()
        self.assertFalse(remote_perm.has_perm(base_lat, base_lng))