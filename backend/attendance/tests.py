from django.test import TestCase
from datetime import time
from nepali_datetime import date as nepali_date
from authentication.models import Account
from organization.models import Organization, Department, Post, Employee
from attendance.models import Attendance, CheckInOut, RemoteWorkPermission, RemoteWorkRequest, AttendanceCorrectionRequest
from rest_framework.test import APIClient
from rest_framework import status


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
        base_lat = 27.7172
        base_lng = 85.3240
        
        RemoteWorkPermission.objects.filter(employee=self.emp).update(
            is_allowed=True,
            remote_lat=base_lat,
            remote_lng=base_lng
        )
        remote_perm = RemoteWorkPermission.objects.get(employee=self.emp)
        
        # Exact same location should return True
        self.assertTrue(remote_perm.has_perm(base_lat, base_lng))
        
        # Location roughly ~10m away
        self.assertTrue(remote_perm.has_perm(base_lat + 0.00005, base_lng + 0.00005))
        
        # Location ~1km away should fail
        self.assertFalse(remote_perm.has_perm(base_lat + 0.01, base_lng))
        
        # If is_allowed is False, should fail
        remote_perm.is_allowed = False
        remote_perm.save()
        self.assertFalse(remote_perm.has_perm(base_lat, base_lng))


class AttendanceAdminRestrictionTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.org = Organization.objects.create(name="Test Org")
        self.dept = Department.objects.create(organization=self.org, department_name="IT")
        self.post = Post.objects.create(department=self.dept, title="Analyst")

        self.admin_user = Account.objects.create(
            email="admin@attendance.test", first_name="Admin", last_name="Boss", is_superuser=True
        )
        self.org.admin_users.add(self.admin_user)

        self.emp_user = Account.objects.create(
            email="emp@attendance.test", first_name="Staff", last_name="Member"
        )
        self.emp = Employee.objects.create(user=self.emp_user, post=self.post)

    def test_admin_cannot_clock_in(self):
        """Admin cannot perform employee clock in."""
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.post('/api/attendance/check-in/', {
            'latitude': 27.7172,
            'longitude': 85.3240,
        })
        self.assertEqual(res.status_code, 403)
        self.assertIn("reserved for employee staff members only", res.data.get('error', ''))

    def test_admin_cannot_clock_out(self):
        """Admin cannot perform employee clock out."""
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.post('/api/attendance/check-out/', {
            'latitude': 27.7172,
            'longitude': 85.3240,
        })
        self.assertEqual(res.status_code, 403)
        self.assertIn("reserved for employee staff members only", res.data.get('error', ''))

    def test_admin_cannot_request_wfh(self):
        """Admin cannot submit WFH request."""
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.post('/api/attendance/remote-requests/', {
            'latitude': 27.7172,
            'longitude': 85.3240,
            'reason': 'Want WFH',
        })
        self.assertEqual(res.status_code, 403)
        self.assertIn("reserved for employee staff members only", res.data.get('error', ''))

    def test_admin_cannot_submit_correction_request(self):
        """Admin cannot submit correction request."""
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.post('/api/attendance/correction-requests/', {
            'requested_date': '2080-01-01',
            'requested_check_in': '09:00:00',
            'requested_check_out': '17:00:00',
            'reason': 'Forgot to clock in',
        })
        self.assertEqual(res.status_code, 403)

    def test_employee_can_request_wfh_and_admin_approve(self):
        """Employee can request WFH, and Admin can approve it."""
        self.client.force_authenticate(user=self.emp_user)
        res = self.client.post('/api/attendance/remote-requests/', {
            'latitude': 27.7172,
            'longitude': 85.3240,
            'reason': 'Work from home due to travel',
        })
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        req_id = res.data['id']

        # Admin approves
        self.client.force_authenticate(user=self.admin_user)
        approve_res = self.client.post(f'/api/attendance/remote-requests/{req_id}/action/', {
            'status': 'approved'
        })
        self.assertEqual(approve_res.status_code, status.HTTP_200_OK)
        req_obj = RemoteWorkRequest.objects.get(id=req_id)
        self.assertEqual(req_obj.status, 'approved')

    def test_employee_can_submit_correction_and_admin_approve(self):
        """Employee can submit correction request, and Admin can approve it."""
        self.client.force_authenticate(user=self.emp_user)
        res = self.client.post('/api/attendance/correction-requests/', {
            'requested_date': '2080-01-05',
            'requested_check_in': '09:30:00',
            'requested_check_out': '17:30:00',
            'reason': 'System network error on clock-in',
        })
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        corr_id = res.data['id']

        # Admin approves
        self.client.force_authenticate(user=self.admin_user)
        action_res = self.client.patch(f'/api/attendance/correction-requests/{corr_id}/action/', {
            'status': 'approved',
            'admin_note': 'Verified with manager'
        })
        self.assertEqual(action_res.status_code, status.HTTP_200_OK)
        corr_obj = AttendanceCorrectionRequest.objects.get(id=corr_id)
        self.assertEqual(corr_obj.status, 'approved')
        # Check Attendance record created
        attendance = Attendance.objects.filter(employee=self.emp, date=nepali_date(2080, 1, 5)).first()
        self.assertIsNotNone(attendance)
        self.assertEqual(attendance.check_ins_outs.count(), 1)