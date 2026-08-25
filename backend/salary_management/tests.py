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
        
        import nepali_datetime
        # Create Employee 1 (Single)
        self.user1 = Account.objects.create(email="user1@test.com", first_name="User", last_name="One")
        self.emp1 = Employee.objects.create(
            user=self.user1, post=self.post, marital_status="single",
            date_of_joining=nepali_datetime.date(2079, 1, 1)
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
            user=self.user2, post=self.post, marital_status="married",
            date_of_joining=nepali_datetime.date(2079, 1, 1)
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

    def test_mid_month_joinee_salary_proration(self):
        """
        Test that an employee joining mid-month (Bhadra 16) only receives
        salary and holidays for their active period in the month.
        """
        import nepali_datetime
        mid_user = Account.objects.create(email="mid_salary@test.com", first_name="Mid", last_name="Salary")
        mid_emp = Employee.objects.create(
            user=mid_user, post=self.post, marital_status="single",
            date_of_joining=nepali_datetime.date(2083, 5, 16)
        )
        Salary.objects.filter(employee=mid_emp).update(
            organization=self.org,
            basic_salary=30000,
            remote_salary=30000,
            ssf=0, tds=0, epf=0
        )

        # In Month 4 (prior to joining): Gross salary must be 0
        gross_m4 = Salary.calculate_gross_salary(mid_emp, year=2083, month=4)
        self.assertEqual(gross_m4, 0.0)

        # In Month 5 (Month of joining: Bhadra has 31 days, joins on 16th -> 16 active days)
        # If employee has 0 attendance, they only get Saturdays falling in days 16..31
        saturdays_16_to_31 = sum(1 for d in range(16, 32) if nepali_datetime.date(2083, 5, d).weekday() == 6)
        gross_m5 = Salary.calculate_gross_salary(mid_emp, year=2083, month=5)
        # Unpaid absences = 31 - saturdays_16_to_31
        expected_gross = max(0, round(30000 - ((31 - saturdays_16_to_31) * 1000.0)))
        self.assertEqual(gross_m5, expected_gross)

    def test_future_joinee_zero_salary(self):
        """
        Test that an employee who hasn't joined yet receives 0.0 gross and net salary.
        """
        import nepali_datetime
        future_user = Account.objects.create(email="future_salary@test.com", first_name="Future", last_name="User")
        future_emp = Employee.objects.create(
            user=future_user, post=self.post, marital_status="single",
            date_of_joining=nepali_datetime.date(2083, 7, 1)
        )
        Salary.objects.filter(employee=future_emp).update(
            organization=self.org,
            basic_salary=30000,
            ssf=0, tds=0, epf=0
        )

        gross = Salary.calculate_gross_salary(future_emp, year=2083, month=5)
        net = Salary.calculate_net_salary(future_emp, year=2083, month=5)
        self.assertEqual(gross, 0.0)
        self.assertEqual(net, 0.0)

    def test_employee_net_salary_api_mid_month_joinee(self):
        """
        Test that the API endpoint returns 0 holidays and 0 net salary
        for months prior to joining date, and prorates accurately in joining month.
        """
        from rest_framework.test import APIClient
        from rest_framework import status
        import nepali_datetime

        api_user = Account.objects.create(email="apijoinee@test.com", first_name="Api", last_name="Joinee")
        api_emp = Employee.objects.create(
            user=api_user, post=self.post, marital_status="single",
            date_of_joining=nepali_datetime.date(2083, 5, 16)
        )
        sal = Salary.objects.filter(employee=api_emp).first()
        sal.basic_salary = 30000
        sal.organization = self.org
        sal.save()

        self.client.force_login(api_user)

        # Month 4 (prior to joining date):
        res_m4 = self.client.get(f'/api/salary/net-salary/{sal.id}/?year=2083&month=4')
        self.assertEqual(res_m4.status_code, status.HTTP_200_OK)
        self.assertEqual(res_m4.data['net_salary'], 0)
        self.assertEqual(res_m4.data['holidays'], 0)

        # Month 5 (Joining month):
        res_m5 = self.client.get(f'/api/salary/net-salary/{sal.id}/?year=2083&month=5')
        self.assertEqual(res_m5.status_code, status.HTTP_200_OK)
        # Holidays in month 5 should only count Saturdays in days 16..31
        saturdays_16_to_31 = sum(1 for d in range(16, 32) if nepali_datetime.date(2083, 5, d).weekday() == 6)
        self.assertEqual(res_m5.data['holidays'], saturdays_16_to_31)


