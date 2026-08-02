from django.test import TestCase
from unittest.mock import patch
from authentication.models import Account
from organization.models import Organization, Department, Post, Employee
from salary_management.models import Salary, SalaryTaxBand

class SalaryCalculationTests(TestCase):
    def setUp(self):
        # Create hierarchy
        self.org = Organization.objects.create(name="Test Org")
        self.dept = Department.objects.create(organization=self.org, department_name="Engineering")
        self.post = Post.objects.create(department=self.dept, title="Developer")
        
        # Create Employee 1 (Single)
        self.user1 = Account.objects.create(email="user1@test.com", first_name="User", last_name="One")
        self.emp1 = Employee.objects.create(
            user=self.user1, post=self.post, marital_status="single"
        )
        # Update the auto-created Salary object
        Salary.objects.filter(employee=self.emp1).update(
            organization=self.org,
            basic_salary=30000,
            remote_salary=20000,
            ssf=0, tds=0, epf=0
        )
        
        # Create Employee 2 (Married)
        self.user2 = Account.objects.create(email="user2@test.com", first_name="User", last_name="Two")
        self.emp2 = Employee.objects.create(
            user=self.user2, post=self.post, marital_status="married"
        )
        # Update the auto-created Salary object
        Salary.objects.filter(employee=self.emp2).update(
            organization=self.org,
            basic_salary=30000,
            remote_salary=20000,
            ssf=0, tds=0, epf=0
        )

    @patch('salary_management.models.total_days_in_month')
    @patch('attendance.models.Attendance.get_attendance_of_selected_month')
    @patch('leave_management.models.LeaveRequest.get_total_paid_leaves')
    def test_30_day_basis_full_attendance(self, mock_leaves, mock_attendance, mock_days_in_month):
        """
        Test that a full month of attendance yields exactly the basic salary
        regardless of whether the month has 29, 30, 31, or 32 days.
        """
        # Mocking a 31-day month
        mock_days_in_month.return_value = 31
        
        # Mock 0 leaves and empty attendance (since we will override holidays to 31 for full paid days)
        # Actually, let's just make holidays_override = 31 to simulate full paid days (e.g. 27 present + 4 holidays)
        mock_leaves.return_value = 0
        mock_attendance.return_value = []

        # If they get paid for all 31 days (holidays_override=31), unpaid absences = max(0, 31 - 31) = 0
        gross = Salary.calculate_gross_salary(
            employee=self.emp1, year=2080, month=1, holidays_override=31
        )
        
        # 30-day basis means basic_salary / 30 = 1000 per day.
        # But base_payout = basic_salary - (unpaid_absences * 1000)
        # base_payout = 30000 - (0 * 1000) = 30000
        self.assertEqual(gross, 30000)

    @patch('salary_management.models.total_days_in_month')
    @patch('attendance.models.Attendance.get_attendance_of_selected_month')
    @patch('leave_management.models.LeaveRequest.get_total_paid_leaves')
    def test_unpaid_absences_deduction(self, mock_leaves, mock_attendance, mock_days_in_month):
        """
        Test that missing days correctly deducts from the basic salary based on a 30-day rate.
        """
        mock_days_in_month.return_value = 30
        mock_leaves.return_value = 0
        mock_attendance.return_value = []
        
        # Simulate only 25 paid days out of a 30-day month (so 5 unpaid absences)
        # per_day_rate = 30000 / 30 = 1000
        # Deduction = 5 * 1000 = 5000
        # Expected payout = 25000
        gross = Salary.calculate_gross_salary(
            employee=self.emp1, year=2080, month=1, holidays_override=25
        )
        self.assertEqual(gross, 25000)

    @patch('salary_management.models.Salary.calculate_gross_salary')
    def test_tax_bands_single_vs_married(self, mock_gross):
        """
        Test that tax bands apply differently based on the marital status of the employee.
        """
        # Set up 2 tax bands:
        # Single: 1% tax
        SalaryTaxBand.objects.create(
            organization=self.org, marital_status="single",
            min_salary=0, max_salary=500000, tax_percentage=1, order=1
        )
        # Married: 0% tax (example)
        SalaryTaxBand.objects.create(
            organization=self.org, marital_status="married",
            min_salary=0, max_salary=500000, tax_percentage=0, order=1
        )
        
        # Mock gross salary to 30000 (Annualized = 360,000)
        mock_gross.return_value = 30000
        
        # Calculate for single
        net_single = Salary.calculate_net_salary(
            employee=self.emp1, year=2080, month=1
        )
        # 360k at 1% = 3600 tax / 12 = 300 monthly tax. 
        # Net = 30000 - 300 = 29700
        self.assertEqual(net_single, 29700)
        
        # Calculate for married
        net_married = Salary.calculate_net_salary(
            employee=self.emp2, year=2080, month=1
        )
        # 360k at 0% = 0 tax.
        # Net = 30000
        self.assertEqual(net_married, 30000)

    @patch('salary_management.models.total_days_in_month')
    @patch('attendance.models.Attendance.get_attendance_of_selected_month')
    @patch('leave_management.models.LeaveRequest.get_total_paid_leaves')
    def test_remote_swap_adjustment(self, mock_leaves, mock_attendance, mock_days_in_month):
        """
        Test that remote days are paid at the remote rate instead of the basic rate.
        """
        mock_days_in_month.return_value = 30
        mock_leaves.return_value = 0
        
        # Create a mock attendance object
        class MockAttendance:
            def __init__(self, is_remote):
                self.is_remote = is_remote
                self.date = "2080-01-01"
            def has_checked_in(self):
                return True
                
        # Simulate 10 days of remote attendance and 0 site attendance
        # (Total paid days will be 10 remote + holidays_override)
        mock_attendance.return_value = [MockAttendance(is_remote=True) for _ in range(10)]
        
        # Assuming 20 holidays (so total paid days = 10 remote + 20 holiday = 30)
        # per_day_rate = 30000 / 30 = 1000
        # remote_rate = 20000 / 30 = 666.666
        # The base payout (paying everything at basic rate) = 30000
        # Remote swap = 10 * (666.666 - 1000) = -3333.333
        # Gross = 30000 - 3333.333 = 26667
        gross = Salary.calculate_gross_salary(
            employee=self.emp1, year=2080, month=1, holidays_override=20
        )
        self.assertEqual(gross, 26667)
