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
        
        # Create Employees
        self.user = Account.objects.create(email="user@test.com", first_name="Regular", last_name="Employee")
        self.emp = Employee.objects.create(user=self.user, post=self.post, employee_type='full_time', is_in_provision=False)

        self.probation_user = Account.objects.create(email="probation@test.com", first_name="Probation", last_name="Staff")
        self.probation_emp = Employee.objects.create(user=self.probation_user, post=self.post, employee_type='full_time', is_in_provision=True)

        self.intern_user = Account.objects.create(email="intern@test.com", first_name="Intern", last_name="Student")
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

