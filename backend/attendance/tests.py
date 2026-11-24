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

        # Uninitialized (0, 0) coordinates should return False even if is_allowed=True
        remote_perm.is_allowed = True
        remote_perm.remote_lat = 0.0
        remote_perm.remote_lng = 0.0
        remote_perm.save()
        self.assertFalse(remote_perm.has_perm(0.0, 0.0))

    def test_end_to_end_remote_checkin_checkout_strict_50m_radius_and_403_status(self):
        """
        Verify end-to-end remote work geofencing on CheckIn and CheckOut:
        1. Outside office without remote permission -> HTTP 403 (not 401)
        2. Employee requests WFH -> /remote-work-permission/me/ shows has_pending_request=True
        3. Admin approves WFH -> RemoteWorkPermission active at (remote_lat, remote_lng)
        4. CheckIn > 50m from approved remote spot -> HTTP 403
        5. CheckIn <= 50m from approved remote spot -> HTTP 200 (is_remote=True)
        6. CheckOut > 50m from approved remote spot -> HTTP 403
        7. CheckOut <= 50m from approved remote spot -> HTTP 200 (is_remote=True)
        8. Disabling OrganizationSettings.enable_remote_attendance blocks remote check-in with HTTP 403
        """
        from organization.models import OrganizationSettings

        admin_user = Account.objects.create(
            email="remote.admin@test.com", first_name="Remote", last_name="Admin", is_superuser=True
        )
        self.org.admin_users.add(admin_user)

        # Configure office at Kathmandu Durbar Square (27.7042, 85.3067) with 100m radius
        org_settings = OrganizationSettings.objects.create(
            organization=self.org,
            office_latitude=27.7042,
            office_longitude=85.3067,
            allowed_attendance_radius=100,
            enable_in_office_attendance=True,
            enable_remote_attendance=True,
        )

        # Employee's remote home spot at Lazimpat (27.7215, 85.3206) ~2.3km from office
        home_lat, home_lng = 27.7215, 85.3206
        cafe_lat, cafe_lng = 27.7300, 85.3300  # ~1.3km away from home (> 50m)

        client = APIClient()
        client.force_authenticate(user=self.user)

        # 1. Outside office without remote approval -> 403 Forbidden (not 401)
        res_no_perm = client.post('/api/attendance/check-in/', {
            'latitude': home_lat,
            'longitude': home_lng,
        })
        self.assertEqual(res_no_perm.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn('office radius', res_no_perm.data['error'].lower())

        # 2. Employee submits WFH request at home coordinates
        req_res = client.post('/api/attendance/remote-requests/', {
            'latitude': home_lat,
            'longitude': home_lng,
            'reason': 'Working from home office',
        })
        self.assertEqual(req_res.status_code, status.HTTP_201_CREATED)
        req_id = req_res.data['id']

        me_pending = client.get('/api/attendance/remote-work-permission/me/')
        self.assertEqual(me_pending.status_code, status.HTTP_200_OK)
        self.assertFalse(me_pending.data['has_remote_permission'])
        self.assertTrue(me_pending.data['has_pending_request'])
        self.assertEqual(me_pending.data['pending_request']['id'], req_id)

        # 3. Admin approves WFH request
        client.force_authenticate(user=admin_user)
        app_res = client.post(f'/api/attendance/remote-requests/{req_id}/action/', {
            'status': 'approved',
        })
        self.assertEqual(app_res.status_code, status.HTTP_200_OK)

        # Verify /me/ now shows active remote permission and no pending request
        client.force_authenticate(user=self.user)
        me_approved = client.get('/api/attendance/remote-work-permission/me/')
        self.assertTrue(me_approved.data['has_remote_permission'])
        self.assertFalse(me_approved.data['has_pending_request'])
        self.assertAlmostEqual(me_approved.data['remote_lat'], home_lat, places=4)

        # 4. Employee tries to check in from a cafe (> 50m from approved remote spot) -> 403 Forbidden
        res_out_of_50m = client.post('/api/attendance/check-in/', {
            'latitude': cafe_lat,
            'longitude': cafe_lng,
        })
        self.assertEqual(res_out_of_50m.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn('50m radius', res_out_of_50m.data['error'].lower())

        # 5. Employee checks in within 50m (~10m) of approved remote home spot -> 200 OK, is_remote=True
        res_valid_ci = client.post('/api/attendance/check-in/', {
            'latitude': home_lat + 0.00005,
            'longitude': home_lng + 0.00005,
        })
        self.assertEqual(res_valid_ci.status_code, status.HTTP_200_OK)
        self.assertTrue(res_valid_ci.data['is_remote'])

        # 6. Employee tries to check out from a cafe (> 50m from approved remote spot) -> 403 Forbidden
        res_bad_co = client.post('/api/attendance/check-out/', {
            'latitude': cafe_lat,
            'longitude': cafe_lng,
        })
        self.assertEqual(res_bad_co.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn('50m radius', res_bad_co.data['error'].lower())

        # 7. Employee checks out within 50m of approved remote home spot -> 200 OK
        res_valid_co = client.post('/api/attendance/check-out/', {
            'latitude': home_lat + 0.00004,
            'longitude': home_lng + 0.00004,
        })
        self.assertEqual(res_valid_co.status_code, status.HTTP_200_OK)
        self.assertTrue(res_valid_co.data['is_remote'])

        # 8. Disabling global remote attendance master switch blocks remote check-in even with permission
        org_settings.enable_remote_attendance = False
        org_settings.save()
        res_master_off = client.post('/api/attendance/check-in/', {
            'latitude': home_lat,
            'longitude': home_lng,
        })
        self.assertEqual(res_master_off.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn('disabled', res_master_off.data['error'].lower())


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


class NepaliCalendarAttendanceDateTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.org = Organization.objects.create(name="Calendar Test Org")
        self.dept = Department.objects.create(organization=self.org, department_name="Ops")
        self.post = Post.objects.create(department=self.dept, title="Engineer")
        self.emp_user = Account.objects.create(
            email="cal.emp@test.com", first_name="Cal", last_name="Emp"
        )
        self.emp = Employee.objects.create(user=self.emp_user, post=self.post)

    def test_bs_2082_and_2083_official_calendar_alignment(self):
        """Backend nepali_datetime matches official BS calendar & Flutter nepali_utils."""
        import datetime as _dt
        import nepali_datetime
        from calendar_app.utilities import total_days_in_month

        # Month lengths for BS 2083
        self.assertEqual(total_days_in_month(2083, 6), 31)   # Asoj
        self.assertEqual(total_days_in_month(2083, 7), 30)   # Kartik
        self.assertEqual(total_days_in_month(2083, 8), 29)   # Mangsir
        self.assertEqual(total_days_in_month(2083, 9), 30)   # Poush
        self.assertEqual(total_days_in_month(2083, 10), 29)  # Magh
        self.assertEqual(total_days_in_month(2100, 12), 31)  # MAXYEAR boundary

        expected_pairs = [
            (_dt.date(2025, 10, 17), nepali_date(2082, 6, 31)),
            (_dt.date(2025, 11, 17), nepali_date(2082, 8, 1)),
            (_dt.date(2026, 4, 14), nepali_date(2083, 1, 1)),
            (_dt.date(2026, 10, 17), nepali_date(2083, 6, 31)),
            (_dt.date(2026, 11, 16), nepali_date(2083, 7, 30)),
            (_dt.date(2026, 11, 17), nepali_date(2083, 8, 1)),
            (_dt.date(2026, 11, 18), nepali_date(2083, 8, 2)),
            (_dt.date(2026, 11, 19), nepali_date(2083, 8, 3)),
            (_dt.date(2026, 12, 15), nepali_date(2083, 8, 29)),
            (_dt.date(2026, 12, 16), nepali_date(2083, 9, 1)),
            (_dt.date(2027, 1, 14), nepali_date(2083, 9, 30)),
            (_dt.date(2027, 1, 15), nepali_date(2083, 10, 1)),
            (_dt.date(2027, 4, 14), nepali_date(2084, 1, 1)),
        ]
        for ad, bs in expected_pairs:
            self.assertEqual(nepali_datetime.date.from_datetime_date(ad), bs)
            self.assertEqual(bs.to_datetime_date(), ad)
            self.assertEqual(bs.weekday(), (ad.weekday() + 1) % 7)

    def test_full_calendar_range_monotonic_and_weekday_consistent(self):
        """Every year from 1975..2100 round-trips cleanly between AD and BS."""
        import datetime as _dt
        import nepali_datetime
        from calendar_app.utilities import total_days_in_month

        for year in range(nepali_datetime.MINYEAR, nepali_datetime.MAXYEAR + 1):
            first_bs = nepali_date(year, 1, 1)
            first_ad = first_bs.to_datetime_date()
            self.assertEqual(nepali_datetime.date.from_datetime_date(first_ad), first_bs)
            self.assertEqual(first_bs.weekday(), (first_ad.weekday() + 1) % 7)

            last_day = total_days_in_month(year, 12)
            last_bs = nepali_date(year, 12, last_day)
            last_ad = last_bs.to_datetime_date()
            self.assertEqual(nepali_datetime.date.from_datetime_date(last_ad), last_bs)
            if year < nepali_datetime.MAXYEAR:
                next_first_ad = nepali_date(year + 1, 1, 1).to_datetime_date()
                self.assertEqual(next_first_ad - last_ad, _dt.timedelta(days=1))

    def test_attendance_list_and_present_days_use_accurate_mangsir_2083_dates(self):
        """Nov 16 (Kartik 30) stays in Kartik; Nov 17-19 show as Mangsir 1-3."""
        import datetime as _dt
        import nepali_datetime

        for ad in (
            _dt.date(2026, 11, 16),  # 2083-07-30 (Kartik 30)
            _dt.date(2026, 11, 17),  # 2083-08-01 (Mangsir 1)
            _dt.date(2026, 11, 18),  # 2083-08-02 (Mangsir 2)
            _dt.date(2026, 11, 19),  # 2083-08-03 (Mangsir 3)
        ):
            att = Attendance.objects.create(
                organization=self.org,
                employee=self.emp,
                date=nepali_datetime.date.from_datetime_date(ad),
            )
            CheckInOut.objects.create(attendance=att, check_in=time(9, 30))

        self.client.force_authenticate(user=self.emp_user)

        mangsir_res = self.client.get('/api/attendance/list/?nepali_year=2083&nepali_month=8')
        self.assertEqual(mangsir_res.status_code, status.HTTP_200_OK)
        mangsir_dates = [row['date'] for row in mangsir_res.data['results']]
        self.assertEqual(mangsir_dates, ['2083-08-03', '2083-08-02', '2083-08-01'])

        kartik_res = self.client.get('/api/attendance/list/?nepali_year=2083&nepali_month=7')
        self.assertEqual(kartik_res.status_code, status.HTTP_200_OK)
        kartik_dates = [row['date'] for row in kartik_res.data['results']]
        self.assertEqual(kartik_dates, ['2083-07-30'])

        stats_res = self.client.get(
            f'/api/attendance/total-working-hour/{self.emp.id}/?nepali_year=2083&nepali_month=8'
        )
        self.assertEqual(stats_res.status_code, status.HTTP_200_OK)
        self.assertEqual(stats_res.data['total_no_of_days_present'], 3)

    def test_correction_request_accepts_31_asoj_2083(self):
        """Asoj 31, 2083 (previously invalid in nepali-datetime 1.0.8.2) is accepted."""
        self.client.force_authenticate(user=self.emp_user)
        res = self.client.post('/api/attendance/correction-requests/', {
            'requested_date': '2083-06-31',
            'requested_check_in': '09:30:00',
            'requested_check_out': '17:30:00',
            'reason': 'Check-in on Asoj 31',
        })
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['requested_date'], '2083-06-31')

    def test_correction_request_rejects_future_date_and_allows_today(self):
        """Correction requests block future BS dates and allow today/past dates."""
        import datetime as _dt
        import nepali_datetime

        today = nepali_datetime.date.today()
        tomorrow = today + _dt.timedelta(days=1)

        self.client.force_authenticate(user=self.emp_user)

        # Future date must be rejected
        future_res = self.client.post('/api/attendance/correction-requests/', {
            'requested_date': str(tomorrow),
            'requested_check_in': '09:30:00',
            'requested_check_out': '17:30:00',
            'reason': 'Future date attempt',
        })
        self.assertEqual(future_res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('requested_date', future_res.data)
        self.assertIn('future date', str(future_res.data['requested_date']).lower())

        # Invalid BS date (Mangsir 30, 2083 does not exist) must be rejected
        invalid_res = self.client.post('/api/attendance/correction-requests/', {
            'requested_date': '2083-08-30',
            'requested_check_in': '09:30:00',
            'reason': 'Invalid date attempt',
        })
        self.assertEqual(invalid_res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('requested_date', invalid_res.data)

        # Today must be allowed
        today_res = self.client.post('/api/attendance/correction-requests/', {
            'requested_date': str(today),
            'requested_check_in': '09:30:00',
            'requested_check_out': '17:30:00',
            'reason': 'Missed check-out today',
        })
        self.assertEqual(today_res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(today_res.data['requested_date'], str(today))

    def test_admin_cannot_approve_future_correction_request_but_can_reject(self):
        """Admin cannot approve a pre-existing future-dated request, but can reject it."""
        import datetime as _dt
        import nepali_datetime

        admin_user = Account.objects.create(
            email="cal.admin@test.com", first_name="Cal", last_name="Admin", is_superuser=True
        )
        self.org.admin_users.add(admin_user)

        tomorrow = nepali_datetime.date.today() + _dt.timedelta(days=1)
        req_obj = AttendanceCorrectionRequest.objects.create(
            employee=self.emp,
            requested_date=tomorrow,
            requested_check_in=time(9, 30),
            requested_check_out=time(17, 30),
            reason='Pre-existing future request',
        )

        self.client.force_authenticate(user=admin_user)
        approve_res = self.client.patch(f'/api/attendance/correction-requests/{req_obj.id}/action/', {
            'status': 'approved',
        })
        self.assertEqual(approve_res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('future date', str(approve_res.data.get('error', '')).lower())

        reject_res = self.client.patch(f'/api/attendance/correction-requests/{req_obj.id}/action/', {
            'status': 'rejected',
            'admin_note': 'Future date not allowed',
        })
        self.assertEqual(reject_res.status_code, status.HTTP_200_OK)


class AttendanceCorrectionPerformancePolicyTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.org = Organization.objects.create(name="Policy Test Org")
        self.dept = Department.objects.create(organization=self.org, department_name="Engineering")
        self.post = Post.objects.create(department=self.dept, title="Developer")

        self.admin_user = Account.objects.create(
            email="policy.admin@test.com", first_name="Policy", last_name="Admin", is_superuser=True
        )
        self.org.admin_users.add(self.admin_user)

        self.emp_user = Account.objects.create(
            email="policy.emp@test.com", first_name="Policy", last_name="Emp"
        )
        self.emp = Employee.objects.create(user=self.emp_user, post=self.post)

    def test_org_settings_correction_policy_defaults_and_admin_update(self):
        self.client.force_authenticate(user=self.emp_user)
        get_res = self.client.get('/api/organization/settings/')
        self.assertEqual(get_res.status_code, status.HTTP_200_OK)
        self.assertEqual(get_res.data['max_free_corrections_per_month'], 2)
        self.assertEqual(get_res.data['correction_penalty_points'], 0.5)
        self.assertFalse(get_res.data['count_rejected_corrections'])

        # Non-admin employee cannot PATCH settings
        emp_patch = self.client.patch('/api/organization/settings/', {
            'max_free_corrections_per_month': 10,
        }, format='json')
        self.assertEqual(emp_patch.status_code, status.HTTP_403_FORBIDDEN)

        # Admin can update settings
        self.client.force_authenticate(user=self.admin_user)
        admin_patch = self.client.patch('/api/organization/settings/', {
            'max_free_corrections_per_month': 3,
            'correction_penalty_points': 1.0,
            'count_rejected_corrections': True,
        }, format='json')
        self.assertEqual(admin_patch.status_code, status.HTTP_200_OK)
        self.assertEqual(admin_patch.data['max_free_corrections_per_month'], 3)
        self.assertEqual(admin_patch.data['correction_penalty_points'], 1.0)
        self.assertTrue(admin_patch.data['count_rejected_corrections'])

    def test_monthly_summary_and_warning_trigger_threshold(self):
        self.client.force_authenticate(user=self.emp_user)

        # 0 requests in Mangsir 2083 (month 8)
        s0 = self.client.get('/api/attendance/correction-requests/monthly-summary/?nepali_year=2083&nepali_month=8')
        self.assertEqual(s0.status_code, status.HTTP_200_OK)
        self.assertEqual(s0.data['count'], 0)
        self.assertEqual(s0.data['max_free'], 2)
        self.assertFalse(s0.data['will_exceed_on_next'])
        self.assertFalse(s0.data['exceeds_limit'])
        self.assertIsNone(s0.data['warning_message'])

        # 1st request
        r1 = self.client.post('/api/attendance/correction-requests/', {
            'requested_date': '2083-08-01',
            'requested_check_in': '09:30:00',
            'requested_check_out': '17:30:00',
            'reason': 'Correction 1',
        })
        self.assertEqual(r1.status_code, status.HTTP_201_CREATED)
        self.assertEqual(r1.data['monthly_correction_count'], 1)
        self.assertFalse(r1.data['exceeds_monthly_limit'])
        self.assertIsNone(r1.data['performance_warning'])

        # 2nd request (reaches free limit = 2)
        r2 = self.client.post('/api/attendance/correction-requests/', {
            'requested_date': '2083-08-02',
            'requested_check_in': '09:30:00',
            'requested_check_out': '17:30:00',
            'reason': 'Correction 2',
        })
        self.assertEqual(r2.status_code, status.HTTP_201_CREATED)
        self.assertEqual(r2.data['monthly_correction_count'], 2)
        self.assertFalse(r2.data['exceeds_monthly_limit'])

        # Summary before 3rd request MUST warn (will_exceed_on_next = True)
        s2 = self.client.get('/api/attendance/correction-requests/monthly-summary/?nepali_year=2083&nepali_month=8')
        self.assertEqual(s2.data['count'], 2)
        self.assertTrue(s2.data['will_exceed_on_next'])
        self.assertFalse(s2.data['exceeds_limit'])
        self.assertEqual(s2.data['next_estimated_penalty'], 0.5)
        self.assertIsNotNone(s2.data['warning_message'])
        self.assertIn('performance score', s2.data['warning_message'].lower())

        # 3rd request (exceeds limit)
        r3 = self.client.post('/api/attendance/correction-requests/', {
            'requested_date': '2083-08-03',
            'requested_check_in': '09:30:00',
            'requested_check_out': '17:30:00',
            'reason': 'Correction 3',
        })
        self.assertEqual(r3.status_code, status.HTTP_201_CREATED)
        self.assertEqual(r3.data['monthly_correction_count'], 3)
        self.assertTrue(r3.data['exceeds_monthly_limit'])
        self.assertEqual(r3.data['estimated_penalty'], 0.5)
        self.assertIsNotNone(r3.data['performance_warning'])

        # Different month (Kartik 2083, month 7) is isolated with count = 0
        s_other = self.client.get('/api/attendance/correction-requests/monthly-summary/?nepali_year=2083&nepali_month=7')
        self.assertEqual(s_other.data['count'], 0)
        self.assertFalse(s_other.data['will_exceed_on_next'])

    def test_rejected_corrections_excluded_by_default_and_included_when_enabled(self):
        req1 = AttendanceCorrectionRequest.objects.create(
            employee=self.emp,
            requested_date=nepali_date(2083, 8, 1),
            reason='Pending req',
            status='pending',
        )
        req2 = AttendanceCorrectionRequest.objects.create(
            employee=self.emp,
            requested_date=nepali_date(2083, 8, 2),
            reason='Rejected req',
            status='rejected',
        )

        self.client.force_authenticate(user=self.emp_user)
        s_default = self.client.get('/api/attendance/correction-requests/monthly-summary/?nepali_year=2083&nepali_month=8')
        self.assertEqual(s_default.data['count'], 1)
        self.assertFalse(s_default.data['will_exceed_on_next'])

        # Enable count_rejected_corrections as Admin
        self.client.force_authenticate(user=self.admin_user)
        self.client.patch('/api/organization/settings/', {'count_rejected_corrections': True}, format='json')

        self.client.force_authenticate(user=self.emp_user)
        s_included = self.client.get('/api/attendance/correction-requests/monthly-summary/?nepali_year=2083&nepali_month=8')
        self.assertEqual(s_included.data['count'], 2)
        self.assertTrue(s_included.data['will_exceed_on_next'])


class MultiSessionTodayStatusTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.org = Organization.objects.create(name="MultiSession Org")
        self.dept = Department.objects.create(organization=self.org, department_name="Eng")
        self.post = Post.objects.create(department=self.dept, title="Engineer")
        self.emp_user = Account.objects.create(
            email="multisession.emp@test.com", first_name="Multi", last_name="Session"
        )
        self.emp = Employee.objects.create(user=self.emp_user, post=self.post)

    def test_today_status_returns_active_session_checkin_time_after_checkout_and_recheckin(self):
        import datetime as py_dt
        from attendance.models import CheckInOut

        self.client.force_authenticate(user=self.emp_user)

        # Before any check-in today
        res0 = self.client.get('/api/attendance/today-status/')
        self.assertEqual(res0.status_code, status.HTTP_200_OK)
        self.assertFalse(res0.data['is_checked_in'])
        self.assertIsNone(res0.data['check_in_time'])
        self.assertIsNone(res0.data['first_check_in_time'])
        self.assertFalse(res0.data['has_checked_out_today'])
        self.assertEqual(res0.data['sessions_count'], 0)

        today = nepali_date.today()
        att = Attendance.objects.create(
            organization=self.org,
            employee=self.emp,
            date=today,
            check_in_lat=27.7172,
            check_in_lng=85.3240,
            is_remote=False,
        )

        # 1. Morning check-in at 10:00:00
        ci1 = CheckInOut.objects.create(
            attendance=att,
            check_in=py_dt.time(10, 0, 0),
        )
        res1 = self.client.get('/api/attendance/today-status/')
        self.assertEqual(res1.status_code, status.HTTP_200_OK)
        self.assertTrue(res1.data['is_checked_in'])
        self.assertEqual(res1.data['check_in_time'], '10:00:00')
        self.assertEqual(res1.data['first_check_in_time'], '10:00:00')
        self.assertFalse(res1.data['has_checked_out_today'])
        self.assertEqual(res1.data['sessions_count'], 1)

        # 2. Checkout at 17:00:00 (5:00 PM)
        ci1.check_out = py_dt.time(17, 0, 0)
        ci1.save()
        res2 = self.client.get('/api/attendance/today-status/')
        self.assertEqual(res2.status_code, status.HTTP_200_OK)
        self.assertFalse(res2.data['is_checked_in'])
        self.assertIsNone(res2.data['check_in_time'])
        self.assertEqual(res2.data['first_check_in_time'], '10:00:00')
        self.assertTrue(res2.data['has_checked_out_today'])
        self.assertEqual(res2.data['sessions_count'], 1)

        # 3. Evening re-check-in at 17:05:00 -> check_in_time MUST be 17:05:00, NOT 10:00:00!
        CheckInOut.objects.create(
            attendance=att,
            check_in=py_dt.time(17, 5, 0),
        )
        res3 = self.client.get('/api/attendance/today-status/')
        self.assertEqual(res3.status_code, status.HTTP_200_OK)
        self.assertTrue(res3.data['is_checked_in'])
        self.assertEqual(res3.data['check_in_time'], '17:05:00')
        self.assertEqual(res3.data['first_check_in_time'], '10:00:00')
        self.assertTrue(res3.data['has_checked_out_today'])
        self.assertEqual(res3.data['sessions_count'], 2)

        # 4. Attendance list history returns both sessions accurately
        list_res = self.client.get(f'/api/attendance/list/?employee={self.emp.id}')
        self.assertEqual(list_res.status_code, status.HTTP_200_OK)
        records = list_res.data['results'] if isinstance(list_res.data, dict) else list_res.data
        self.assertEqual(len(records), 1)
        self.assertEqual(
            records[0]['history'],
            [
                {'in': '10:00:00', 'out': '17:00:00'},
                {'in': '17:05:00', 'out': None},
            ],
        )



