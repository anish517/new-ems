from django.test import TestCase
from nepali_datetime import date as nepali_date
from authentication.models import Account
from organization.models import Organization, Department, Post, Employee
from leave_management.models import LeaveType, LeaveBalance, LeaveRequest

class LeaveManagementTests(TestCase):
    def setUp(self):
        # Create hierarchy
        self.org = Organization.objects.create(name="Test Org")
        self.dept = Department.objects.create(organization=self.org, department_name="Engineering")
        self.post = Post.objects.create(department=self.dept, title="Developer")
        
        # Create Employee
        self.user = Account.objects.create(email="user@test.com", first_name="Test", last_name="User")
        self.emp = Employee.objects.create(user=self.user, post=self.post)
        
        # Create Leave Type and Balance
        self.leave_type = LeaveType.objects.create(
            organization=self.org, name="Sick Leave", quota=12
        )
        self.leave_balance = LeaveBalance.objects.create(
            organization=self.org, employee=self.emp, leave_type=self.leave_type, quota=12, leaves_taken=0
        )

    def test_leave_request_no_days_calculation(self):
        """
        Test that no_days calculates correctly for full days and half days.
        """
        # 1. Single full day (Friday)
        req_single = LeaveRequest.objects.create(
            organization=self.org, employee=self.emp, type=self.leave_type,
            from_date=nepali_date(2080, 1, 1), till_date=nepali_date(2080, 1, 1),
            is_half_day=False
        )
        self.assertEqual(req_single.no_days, 1.0)
        
        # 2. Multi-day spanning Saturday (Friday to Sunday = 2 working days, Saturday excluded)
        req_multi_weekend = LeaveRequest.objects.create(
            organization=self.org, employee=self.emp, type=self.leave_type,
            from_date=nepali_date(2080, 1, 1), till_date=nepali_date(2080, 1, 3),
            is_half_day=False
        )
        self.assertEqual(req_multi_weekend.no_days, 2.0)

        # 3. Multi-day with no weekend (Sunday to Tuesday = 3 working days)
        req_multi_weekdays = LeaveRequest.objects.create(
            organization=self.org, employee=self.emp, type=self.leave_type,
            from_date=nepali_date(2080, 1, 3), till_date=nepali_date(2080, 1, 5),
            is_half_day=False
        )
        self.assertEqual(req_multi_weekdays.no_days, 3.0)
        
        # 4. Half day
        req_half = LeaveRequest.objects.create(
            organization=self.org, employee=self.emp, type=self.leave_type,
            from_date=nepali_date(2080, 1, 1), till_date=nepali_date(2080, 1, 1),
            is_half_day=True, half_day_period="First Half"
        )
        self.assertEqual(req_half.no_days, 0.5)


    def test_get_total_paid_and_unpaid_leaves(self):
        """
        Test the static methods for aggregating paid and unpaid leaves for a given month.
        """
        # Paid leave (1 day)
        LeaveRequest.objects.create(
            organization=self.org, employee=self.emp, type=self.leave_type,
            from_date=nepali_date(2080, 1, 5), till_date=nepali_date(2080, 1, 5),
            is_paid=True, is_approved=True
        )
        
        # Unpaid half-day leave (0.5 days)
        LeaveRequest.objects.create(
            organization=self.org, employee=self.emp, type=self.leave_type,
            from_date=nepali_date(2080, 1, 10), till_date=nepali_date(2080, 1, 10),
            is_paid=False, is_approved=True, is_half_day=True
        )
        
        # Unapproved paid leave (should be ignored)
        LeaveRequest.objects.create(
            organization=self.org, employee=self.emp, type=self.leave_type,
            from_date=nepali_date(2080, 1, 15), till_date=nepali_date(2080, 1, 15),
            is_paid=True, is_approved=False
        )
        
        # Different month leave (should be ignored for month 1)
        LeaveRequest.objects.create(
            organization=self.org, employee=self.emp, type=self.leave_type,
            from_date=nepali_date(2080, 2, 5), till_date=nepali_date(2080, 2, 5),
            is_paid=True, is_approved=True
        )
        
        # Calculate totals for month 1
        total_paid = LeaveRequest.get_total_paid_leaves(self.emp, 2080, 1)
        total_unpaid = LeaveRequest.get_total_unpaid_leaves(self.emp, 2080, 1)
        
        self.assertEqual(total_paid, 1)
        self.assertEqual(total_unpaid, 0.5)
