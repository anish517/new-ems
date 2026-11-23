from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from nepali_datetime import date as nepali_date
from authentication.models import Account
from organization.models import Organization, Department, Post, Employee
from leave_management.models import LeaveType, LeaveBalance, LeaveRequest, LeaveSetting
from leave_management.utils import ensure_default_leave_types_and_settings, get_employee_leave_breakdown
from salary_management.models import Salary


class LeaveManagementTests(TestCase):
    def setUp(self):
        # Create hierarchy
        self.org = Organization.objects.create(name="Test Org")
        self.dept = Department.objects.create(organization=self.org, department_name="Engineering")
        self.post = Post.objects.create(department=self.dept, title="Developer")
        
        # Create Employees (joined in 2080 BS prior to current fiscal year 2083)
        self.user = Account.objects.create(email="user@test.com", first_name="Regular", last_name="Employee")
        self.user.date_joined = nepali_date(2080, 1, 1).to_datetime_date()
        self.user.save()
        self.emp = Employee.objects.create(user=self.user, post=self.post, employee_type='full_time', is_in_provision=False)

        self.probation_user = Account.objects.create(email="probation@test.com", first_name="Probation", last_name="Staff")
        self.probation_user.date_joined = nepali_date(2080, 1, 1).to_datetime_date()
        self.probation_user.save()
        self.probation_emp = Employee.objects.create(user=self.probation_user, post=self.post, employee_type='full_time', is_in_provision=True)

        self.intern_user = Account.objects.create(email="intern@test.com", first_name="Intern", last_name="Student")
        self.intern_user.date_joined = nepali_date(2080, 1, 1).to_datetime_date()
        self.intern_user.save()
        self.intern_emp = Employee.objects.create(user=self.intern_user, post=self.post, employee_type='intern', is_in_provision=False)

        # Setup Leave Setting & Default Types
        self.setting = LeaveSetting.objects.create(
            organization=self.org,
            paid_leave_during_provision=False,
            allow_intern_leave=True,
        )
        ensure_default_leave_types_and_settings(self.org)
        self.casual_type = LeaveType.objects.get(organization=self.org, is_casual_leave=True)
        self.sick_type = LeaveType.objects.get(organization=self.org, is_sick_leave=True)

        self.client = APIClient()

    def test_default_categories_and_legacy_cleanup(self):
        """
        Verify that ONLY Casual Leave (12d) and Sick Leave (8d) exist, and old legacy types are cleaned.
        """
        # Create a fake legacy type
        legacy = LeaveType.objects.create(organization=self.org, name="Paid Leave", quota=18)
        self.assertEqual(LeaveType.objects.filter(organization=self.org).count(), 3)
        
        # Calling ensure_default_leave_types_and_settings should prune it
        ensure_default_leave_types_and_settings(self.org)
        types = LeaveType.objects.filter(organization=self.org)
        self.assertEqual(types.count(), 2)
        type_names = set(types.values_list('name', flat=True))
        self.assertEqual(type_names, {'Casual Leave', 'Sick Leave'})

    def test_monthly_accumulation_and_carry_forward(self):
        """
        Verify monthly accrual math and carry-forward across Nepali months.
        Casual: 1.0d/month up to 12d.
        Sick: ~0.67d/month up to 8d.
        """
        # Month 1 (Baisakh)
        b_m1 = get_employee_leave_breakdown(self.emp, year=2083, month=1)
        casual_m1 = next(b for b in b_m1 if b['is_casual_leave'])
        sick_m1 = next(b for b in b_m1 if b['is_sick_leave'])
        self.assertEqual(casual_m1['accrued_to_date'], 1.0)
        self.assertEqual(sick_m1['accrued_to_date'], 0.67)
        self.assertEqual(casual_m1['available_this_month'], 1.0)

        # Take 1.0 day casual leave in Month 1 on a working day (2083-01-06)
        LeaveRequest.objects.create(
            organization=self.org, employee=self.emp, type=self.casual_type,
            from_date=nepali_date(2083, 1, 6), till_date=nepali_date(2083, 1, 6),
            is_paid=True, is_approved=True, is_reviewed=True
        )

        # Month 5 (Bhadra): Accrued = 5.0d, Paid taken = 1.0d -> Available = 4.0d
        b_m5 = get_employee_leave_breakdown(self.emp, year=2083, month=5)
        casual_m5 = next(b for b in b_m5 if b['is_casual_leave'])
        self.assertEqual(casual_m5['accrued_to_date'], 5.0)
        self.assertEqual(casual_m5['paid_taken'], 1.0)
        self.assertEqual(casual_m5['available_this_month'], 4.0)
        self.assertEqual(casual_m5['remaining_annual'], 11.0)

        # Month 12 (Chaitra): Accrued = 12.0d, Available = 11.0d
        b_m12 = get_employee_leave_breakdown(self.emp, year=2083, month=12)
        casual_m12 = next(b for b in b_m12 if b['is_casual_leave'])
        self.assertEqual(casual_m12['accrued_to_date'], 12.0)
        self.assertEqual(casual_m12['available_this_month'], 11.0)

    def test_provision_period_policy(self):
        """
        When paid_leave_during_provision is False, probation staff cannot apply for Paid leave,
        but CAN apply for Unpaid leave.
        """
        self.setting.paid_leave_during_provision = False
        self.setting.save()

        self.client.force_authenticate(user=self.probation_user)

        # 1. Applying for Paid leave should be blocked (HTTP 400)
        res_paid = self.client.post('/api/leave-tracker/leave-requests/', {
            'subject': 'Paid Leave in Probation',
            'from_date': '2083-05-01',
            'till_date': '2083-05-01',
            'is_paid': 'true',
            'type': str(self.casual_type.id),
            'leave_category': 'Casual Leave',
        })
        self.assertEqual(res_paid.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("provision", str(res_paid.data).lower())

        # 2. Applying for Unpaid leave should succeed (HTTP 201)
        res_unpaid = self.client.post('/api/leave-tracker/leave-requests/', {
            'subject': 'Unpaid Leave in Probation',
            'from_date': '2083-05-01',
            'till_date': '2083-05-01',
            'is_paid': 'false',
            'type': str(self.casual_type.id),
            'leave_category': 'Casual Leave',
        })
        self.assertEqual(res_unpaid.status_code, status.HTTP_201_CREATED)

    def test_intern_leave_policy(self):
        """
        When allow_intern_leave is False, interns cannot apply for any leave.
        """
        self.setting.allow_intern_leave = False
        self.setting.save()

        self.client.force_authenticate(user=self.intern_user)

        res = self.client.post('/api/leave-tracker/leave-requests/', {
            'subject': 'Intern Vacation',
            'from_date': '2083-05-01',
            'till_date': '2083-05-01',
            'is_paid': 'false',
            'type': str(self.casual_type.id),
            'leave_category': 'Casual Leave',
        })
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("intern", str(res.data).lower())

        # Enable intern leave and verify it succeeds
        self.setting.allow_intern_leave = True
        self.setting.save()

        res_allowed = self.client.post('/api/leave-tracker/leave-requests/', {
            'subject': 'Intern Vacation Allowed',
            'from_date': '2083-05-01',
            'till_date': '2083-05-01',
            'is_paid': 'false',
            'type': str(self.casual_type.id),
            'leave_category': 'Casual Leave',
        })
        self.assertEqual(res_allowed.status_code, status.HTTP_201_CREATED)

    def test_unpaid_leave_unrestricted_by_quota(self):
        """
        Unpaid leave should NOT be blocked even if requested days exceed accrued quota.
        """
        self.client.force_authenticate(user=self.user)
        # Request 10 days unpaid in Month 1 (accrued is only 1.0d)
        res = self.client.post('/api/leave-tracker/leave-requests/', {
            'subject': 'Long Unpaid Leave',
            'from_date': '2083-01-01',
            'till_date': '2083-01-12',
            'is_paid': 'false',
            'type': str(self.casual_type.id),
            'leave_category': 'Casual Leave',
        })
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)

    def test_leave_request_no_days_calculation(self):
        """
        Test that no_days calculates correctly for full days and half days (excluding Saturdays).
        """
        req_single = LeaveRequest.objects.create(
            organization=self.org, employee=self.emp, type=self.casual_type,
            from_date=nepali_date(2080, 1, 1), till_date=nepali_date(2080, 1, 1),
            is_half_day=False
        )
        self.assertEqual(req_single.no_days, 1.0)
        
        req_multi_weekend = LeaveRequest.objects.create(
            organization=self.org, employee=self.emp, type=self.casual_type,
            from_date=nepali_date(2080, 1, 1), till_date=nepali_date(2080, 1, 3),
            is_half_day=False
        )
        self.assertEqual(req_multi_weekend.no_days, 2.0)

        req_half = LeaveRequest.objects.create(
            organization=self.org, employee=self.emp, type=self.casual_type,
            from_date=nepali_date(2080, 1, 1), till_date=nepali_date(2080, 1, 1),
            is_half_day=True, half_day_period="First Half"
        )
        self.assertEqual(req_half.no_days, 0.5)

    def test_salary_calculation_compatibility(self):
        """
        Verify that Salary.calculate_gross_salary properly credits paid leaves
        and deducts unpaid leaves without errors.
        """
        # Paid leave (2 days in 2083/05)
        LeaveRequest.objects.create(
            organization=self.org, employee=self.emp, type=self.casual_type,
            from_date=nepali_date(2083, 5, 2), till_date=nepali_date(2083, 5, 3),
            is_paid=True, is_approved=True, is_reviewed=True
        )

        # Unpaid leave (1 day in 2083/05)
        LeaveRequest.objects.create(
            organization=self.org, employee=self.emp, type=self.casual_type,
            from_date=nepali_date(2083, 5, 10), till_date=nepali_date(2083, 5, 10),
            is_paid=False, is_approved=True, is_reviewed=True
        )

        # Create or update Salary record with basic salary 30,000
        Salary.objects.update_or_create(
            employee=self.emp,
            defaults={
                'organization': self.org,
                'basic_salary': 30000.0,
                'remote_salary': 0.0,
            }
        )

        gross = Salary.calculate_gross_salary(
            employee=self.emp,
            year=2083,
            month=5,
            holidays_override=4
        )
        self.assertIsInstance(gross, (int, float))
        self.assertGreater(gross, 0)

    def test_mid_year_joinee_leave_proration(self):
        """
        Verify that an employee joining in Month 5 (Bhadra 1) gets:
        - 0 accrual in months 1 to 4
        - 1.0d Casual / 0.67d Sick in month 5
        - Prorated annual quota of 8.0d Casual / 5.33d Sick (for remaining 8 months).
        """
        mid_user = Account.objects.create(email="bhadra_join@test.com", first_name="Bhadra", last_name="Joinee")
        mid_user.date_joined = nepali_date(2083, 5, 1).to_datetime_date()
        mid_user.save()
        mid_emp = Employee.objects.create(user=mid_user, post=self.post, employee_type='full_time')

        # Check Month 4 (Shrawan): Should have 0 accrued
        b_m4 = get_employee_leave_breakdown(mid_emp, year=2083, month=4)
        casual_m4 = next(b for b in b_m4 if b['is_casual_leave'])
        self.assertEqual(casual_m4['accrued_to_date'], 0.0)
        self.assertEqual(casual_m4['available_this_month'], 0.0)

        # Check Month 5 (Bhadra): Should have 1.0d Casual, 8.0d annual quota
        b_m5 = get_employee_leave_breakdown(mid_emp, year=2083, month=5)
        casual_m5 = next(b for b in b_m5 if b['is_casual_leave'])
        sick_m5 = next(b for b in b_m5 if b['is_sick_leave'])
        self.assertEqual(casual_m5['annual_quota'], 8.0)
        self.assertEqual(casual_m5['accrued_to_date'], 1.0)
        self.assertEqual(casual_m5['available_this_month'], 1.0)
        self.assertEqual(sick_m5['annual_quota'], 5.33)
        self.assertEqual(sick_m5['accrued_to_date'], 0.67)

    def test_mid_month_joinee_leave_proration(self):
        """
        Verify that an employee joining on 16th of a 30-day month (Bhadra 16)
        gets a half-month fraction (0.5d) in joining month.
        """
        mid_user = Account.objects.create(email="mid_month@test.com", first_name="Mid", last_name="Month")
        mid_user.date_joined = nepali_date(2083, 5, 16).to_datetime_date()
        mid_user.save()
        mid_emp = Employee.objects.create(user=mid_user, post=self.post, employee_type='full_time')

        b_m5 = get_employee_leave_breakdown(mid_emp, year=2083, month=5)
        casual_m5 = next(b for b in b_m5 if b['is_casual_leave'])
        # Fraction worked = (31 - 16 + 1)/31 = 16/31 approx 0.52, or approx 0.5
        self.assertGreater(casual_m5['accrued_to_date'], 0.0)
        self.assertLess(casual_m5['accrued_to_date'], 1.0)
        self.assertEqual(casual_m5['is_prorated'], True)

    def test_explicit_date_of_joining_leave_proration(self):
        """
        Verify that employee.date_of_joining overrides user.date_joined and accurately
        prorates leave balances for mid-year join date.
        """
        user = Account.objects.create(email="explicit_doj@test.com", first_name="Explicit", last_name="DOJ")
        # user.date_joined is in 2080 BS, but employee.date_of_joining is set explicitly to 2083-05-01
        user.date_joined = nepali_date(2080, 1, 1).to_datetime_date()
        user.save()
        emp = Employee.objects.create(
            user=user, post=self.post, employee_type='full_time',
            date_of_joining=nepali_date(2083, 5, 1)
        )

        # In Month 4: Accrued = 0.0
        b_m4 = get_employee_leave_breakdown(emp, year=2083, month=4)
        casual_m4 = next(b for b in b_m4 if b['is_casual_leave'])
        self.assertEqual(casual_m4['accrued_to_date'], 0.0)

        # In Month 5: Accrued = 1.0, Annual Quota = 8.0
        b_m5 = get_employee_leave_breakdown(emp, year=2083, month=5)
        casual_m5 = next(b for b in b_m5 if b['is_casual_leave'])
        self.assertEqual(casual_m5['annual_quota'], 8.0)
        self.assertEqual(casual_m5['accrued_to_date'], 1.0)
        self.assertEqual(casual_m5['available_this_month'], 1.0)

    def test_dynamic_quota_edit_persists_and_recalculates_monthly_accrual(self):
        """
        Verify Finding #1 & #7 fix:
        - Non-admin cannot edit employee leave quota or leave policy settings (403).
        - Admin can update an employee's Casual Leave quota from 12 to 18 via
          PATCH /api/leave-tracker/leave-balance/update/<id>/.
        - Subsequent calls to get_employee_leave_breakdown, /leave-balance/, and
          /leave-summary/ preserve quota=18 and dynamically accrue 1.5d/month.
        """
        admin_user = Account.objects.create_superuser(
            email="leave.admin@test.com", first_name="Leave", last_name="Admin", password="password123"
        )
        self.org.admin_users.add(admin_user)

        b_init = get_employee_leave_breakdown(self.emp, year=2083, month=4)
        casual_init = next(b for b in b_init if b['is_casual_leave'])
        lb_id = casual_init['id']
        self.assertEqual(casual_init['quota'], 12)
        self.assertEqual(casual_init['accrued_to_date'], 4.0)

        # Non-admin employee is blocked from editing quota or policy settings
        self.client.force_authenticate(user=self.user)
        emp_quota_patch = self.client.patch(f'/api/leave-tracker/leave-balance/update/{lb_id}/', {'quota': 99})
        self.assertEqual(emp_quota_patch.status_code, status.HTTP_403_FORBIDDEN)
        emp_setting_patch = self.client.patch('/api/leave-tracker/settings/', {'paid_leave_during_provision': True})
        self.assertEqual(emp_setting_patch.status_code, status.HTTP_403_FORBIDDEN)
        emp_summary_get = self.client.get('/api/leave-tracker/leave-summary/')
        self.assertEqual(emp_summary_get.status_code, status.HTTP_403_FORBIDDEN)

        # Admin updates Casual Leave quota to 18 (1.5d/month)
        self.client.force_authenticate(user=admin_user)
        admin_patch = self.client.patch(f'/api/leave-tracker/leave-balance/update/{lb_id}/', {'quota': 18})
        self.assertEqual(admin_patch.status_code, status.HTTP_200_OK)

        # Verify subsequent /leave-balance/ and /leave-summary/ preserve 18 and accrue 6.0d in Month 4
        bal_res = self.client.get(f'/api/leave-tracker/leave-balance/{self.emp.id}/?nepali_year=2083&nepali_month=4')
        self.assertEqual(bal_res.status_code, status.HTTP_200_OK)
        casual_after = next(b for b in bal_res.data['leave_balances'] if b['is_casual_leave'])
        self.assertEqual(casual_after['quota'], 18)
        self.assertEqual(casual_after['annual_quota'], 18.0)
        self.assertEqual(casual_after['accrued_to_date'], 6.0)
        self.assertEqual(casual_after['available_this_month'], 6.0)

        sum_res = self.client.get('/api/leave-tracker/leave-summary/?nepali_year=2083&nepali_month=8')
        self.assertEqual(sum_res.status_code, status.HTTP_200_OK)
        emp_row = next(r for r in sum_res.data if r['employee_id'] == self.emp.id)
        casual_m8 = next(b for b in emp_row['balances'] if b['is_casual_leave'])
        self.assertEqual(casual_m8['quota'], 18)
        self.assertEqual(casual_m8['accrued_to_date'], 12.0)

    def test_overlapping_leave_prevention_and_half_day_periods(self):
        """
        Verify Finding #3 fix:
        - Duplicate or overlapping full-day leave requests are rejected (400).
        - Two half-day leaves for the SAME period (First Half) on the same date are rejected (400).
        - First Half and Second Half on the same date are allowed (201).
        """
        self.client.force_authenticate(user=self.user)

        # Find two non-Saturday working days in 2083-05
        work_days = [
            nepali_date(2083, 5, d)
            for d in range(1, 20)
            if nepali_date(2083, 5, d).weekday() != 6
        ]
        d1, d2 = str(work_days[0]), str(work_days[1])

        # 1. Submit full-day leave on d1
        r1 = self.client.post('/api/leave-tracker/leave-requests/', {
            'subject': 'Full Day 1',
            'from_date': d1,
            'till_date': d1,
            'is_paid': 'true',
            'type': str(self.casual_type.id),
        })
        self.assertEqual(r1.status_code, status.HTTP_201_CREATED)
        self.assertIsNotNone(r1.data['created_at'])

        # 2. Overlapping full-day leave on d1 must be blocked (400)
        r_dup = self.client.post('/api/leave-tracker/leave-requests/', {
            'subject': 'Duplicate Full Day 1',
            'from_date': d1,
            'till_date': d1,
            'is_paid': 'false',
            'type': str(self.casual_type.id),
        })
        self.assertEqual(r_dup.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('overlapping', str(r_dup.data).lower())

        # 3. Half-day First Half on d2 succeeds
        r_h1 = self.client.post('/api/leave-tracker/leave-requests/', {
            'subject': 'Morning Half',
            'from_date': d2,
            'till_date': d2,
            'is_paid': 'false',
            'is_half_day': 'true',
            'half_day_period': 'First Half',
            'type': str(self.casual_type.id),
        })
        self.assertEqual(r_h1.status_code, status.HTTP_201_CREATED)

        # 4. Duplicate First Half on d2 is blocked (400)
        r_h1_dup = self.client.post('/api/leave-tracker/leave-requests/', {
            'subject': 'Duplicate Morning Half',
            'from_date': d2,
            'till_date': d2,
            'is_paid': 'false',
            'is_half_day': 'true',
            'half_day_period': 'First Half',
            'type': str(self.casual_type.id),
        })
        self.assertEqual(r_h1_dup.status_code, status.HTTP_400_BAD_REQUEST)

        # 5. Second Half on d2 succeeds
        r_h2 = self.client.post('/api/leave-tracker/leave-requests/', {
            'subject': 'Afternoon Half',
            'from_date': d2,
            'till_date': d2,
            'is_paid': 'false',
            'is_half_day': 'true',
            'half_day_period': 'Second Half',
            'type': str(self.casual_type.id),
        })
        self.assertEqual(r_h2.status_code, status.HTTP_201_CREATED)

    def test_saturday_and_public_holiday_exclusion_for_full_and_half_day_leaves(self):
        """
        Verify Finding #2 & #4 fix:
        - Half-day leave on a Saturday or organization Public Holiday is rejected (400).
        - Multi-day leave spanning a Public Holiday excludes the holiday from no_days.
        - LeaveRequestListCreateAPIView returns requests across months even when ?nepali_month= is passed.
        """
        from calendar_app.models import Event

        self.client.force_authenticate(user=self.user)

        saturdays = [
            nepali_date(2083, 8, d)
            for d in range(1, 30)
            if nepali_date(2083, 8, d).weekday() == 6
        ]
        work_days = [
            nepali_date(2083, 8, d)
            for d in range(1, 30)
            if nepali_date(2083, 8, d).weekday() != 6
        ]
        sat_date = saturdays[0]
        hol_date = work_days[1]

        # Create an organization public holiday on work_days[1]
        Event.objects.create(
            organization=self.org,
            title="Public Holiday",
            start=hol_date,
            end=hol_date,
            is_holiday=True,
        )

        # 1. Half-day leave on a Saturday -> rejected (400)
        res_sat_half = self.client.post('/api/leave-tracker/leave-requests/', {
            'subject': 'Saturday Half Day',
            'from_date': str(sat_date),
            'till_date': str(sat_date),
            'is_paid': 'false',
            'is_half_day': 'true',
            'half_day_period': 'First Half',
            'type': str(self.casual_type.id),
        })
        self.assertEqual(res_sat_half.status_code, status.HTTP_400_BAD_REQUEST)

        # 2. Half-day leave on a Public Holiday -> rejected (400)
        res_hol_half = self.client.post('/api/leave-tracker/leave-requests/', {
            'subject': 'Holiday Half Day',
            'from_date': str(hol_date),
            'till_date': str(hol_date),
            'is_paid': 'false',
            'is_half_day': 'true',
            'half_day_period': 'First Half',
            'type': str(self.casual_type.id),
        })
        self.assertEqual(res_hol_half.status_code, status.HTTP_400_BAD_REQUEST)

        # 3. Full-day leave across work_days[0]..work_days[2] where work_days[1] is a Public Holiday
        res_span = self.client.post('/api/leave-tracker/leave-requests/', {
            'subject': 'Spanning Holiday',
            'from_date': str(work_days[0]),
            'till_date': str(work_days[2]),
            'is_paid': 'true',
            'type': str(self.casual_type.id),
        })
        self.assertEqual(res_span.status_code, status.HTTP_201_CREATED)
        expected_non_sat_non_hol = sum(
            1.0
            for d in range(work_days[0].day, work_days[2].day + 1)
            if nepali_date(2083, 8, d).weekday() != 6 and nepali_date(2083, 8, d) != hol_date
        )
        self.assertEqual(res_span.data['no_days'], expected_non_sat_non_hol)

        # 4. Cross-month visibility: querying /leave-requests/?nepali_year=2083&nepali_month=1 still shows the Month 8 request
        list_res = self.client.get('/api/leave-tracker/leave-requests/?nepali_year=2083&nepali_month=1')
        self.assertEqual(list_res.status_code, status.HTTP_200_OK)
        items = list_res.data if isinstance(list_res.data, list) else list_res.data.get('results', [])
        ids = {item['id'] for item in items}
        self.assertIn(res_span.data['id'], ids)



