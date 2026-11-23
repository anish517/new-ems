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

    @patch('salary_management.models.total_days_in_month')
    @patch('attendance.models.Attendance.get_attendance_of_selected_month')
    @patch('leave_management.models.LeaveRequest.get_total_paid_leaves')
    def test_29_30_31_32_day_months_strict_30_day_basis_and_zero_paid_days(
        self, mock_leaves, mock_attendance, mock_days_in_month
    ):
        """
        Verify strict 30-day basis across 29, 30, 31, and 32-day B.S. months:
        - Full attendance (0 absences) -> 100% basic_salary (30,000)
        - 2 unpaid absences -> 30,000 - 2 * (30,000 / 30) = 28,000 in every month length
        - 0 paid days in a 29-day month -> 0.0 (never 1 phantom day from 30 - 29)
        """
        mock_leaves.return_value = 0
        mock_attendance.return_value = []

        for m_len in (29, 30, 31, 32):
            mock_days_in_month.return_value = m_len
            # Full attendance
            full_gross = Salary.calculate_gross_salary(
                employee=self.emp1, year=2083, month=1, holidays_override=m_len
            )
            self.assertEqual(full_gross, 30000)

            # 2 unpaid absences
            two_abs_gross = Salary.calculate_gross_salary(
                employee=self.emp1, year=2083, month=1, holidays_override=m_len - 2
            )
            self.assertEqual(two_abs_gross, 28000)

            # 0 paid days -> must be strictly 0.0 even in a 29-day month
            zero_gross = Salary.calculate_gross_salary(
                employee=self.emp1, year=2083, month=1, holidays_override=0
            )
            self.assertEqual(zero_gross, 0.0)

    def test_paid_and_unpaid_half_day_leave_with_checkin_no_double_count(self):
        """
        Verify that:
        - Approved PAID half-day leave + check-in on that date credits 1.0 day total (not 1.5 days).
        - Approved UNPAID half-day leave + check-in on that date credits 0.5 day total (not 1.0 day).
        """
        import datetime as py_dt
        import nepali_datetime
        from attendance.models import Attendance, CheckInOut
        from leave_management.models import LeaveRequest, LeaveType

        casual = LeaveType.objects.create(organization=self.org, name="Casual Leave", quota=12, is_casual_leave=True)
        # Find two non-Saturday working days in 2083-08 (Mangsir 2083 = 29 days)
        work_days = [
            nepali_datetime.date(2083, 8, d)
            for d in range(1, 30)
            if nepali_datetime.date(2083, 8, d).weekday() != 6
        ]
        paid_half_day = work_days[0]
        unpaid_half_day = work_days[1]

        # Check in on all working days except work_days[2] (1 full day unpaid absence)
        absent_day = work_days[2]
        for wd in work_days:
            if wd == absent_day:
                continue
            att = Attendance.objects.create(
                organization=self.org, employee=self.emp1, date=wd, is_remote=False
            )
            CheckInOut.objects.create(attendance=att, check_in=py_dt.time(9, 30), check_out=py_dt.time(17, 30))

        # 1. Paid half-day leave on paid_half_day (where emp1 also checked in for the other half)
        LeaveRequest.objects.create(
            organization=self.org,
            employee=self.emp1,
            type=casual,
            from_date=paid_half_day,
            till_date=paid_half_day,
            subject="Paid Half Day",
            is_half_day=True,
            is_paid=True,
            is_approved=True,
        )
        # Paid half-day + check-in should NOT cancel out absent_day (still 1.0 day unpaid absence -> 29,000)
        gross_with_paid_half = Salary.calculate_gross_salary(self.emp1, year=2083, month=8)
        self.assertEqual(gross_with_paid_half, 29000)

        # 2. Unpaid half-day leave on unpaid_half_day (where emp1 also checked in for the other half)
        LeaveRequest.objects.create(
            organization=self.org,
            employee=self.emp1,
            type=casual,
            from_date=unpaid_half_day,
            till_date=unpaid_half_day,
            subject="Unpaid Half Day",
            is_half_day=True,
            is_paid=False,
            is_approved=True,
        )
        # Now total unpaid absences = 1.0 (absent_day) + 0.5 (unpaid_half_day) = 1.5 days -> 28,500
        gross_with_both = Salary.calculate_gross_salary(self.emp1, year=2083, month=8)
        self.assertEqual(gross_with_both, 28500)

    def test_holiday_saturday_and_checkin_overlap_deduplication(self):
        """
        Verify that:
        - A holiday event falling on a Saturday is not double-counted with count_saturdays.
        - Checking in on a Saturday or Public Holiday does not erase a weekday absence.
        - Cross-month multi-day leaves clip strictly to each month's boundaries.
        """
        import datetime as py_dt
        import nepali_datetime
        from attendance.models import Attendance, CheckInOut
        from calendar_app.models import Event
        from calendar_app.utilities import count_holidays, count_saturdays
        from leave_management.models import LeaveRequest, LeaveType

        saturdays = [
            nepali_datetime.date(2083, 8, d)
            for d in range(1, 30)
            if nepali_datetime.date(2083, 8, d).weekday() == 6
        ]
        work_days = [
            nepali_datetime.date(2083, 8, d)
            for d in range(1, 30)
            if nepali_datetime.date(2083, 8, d).weekday() != 6
        ]

        # Create a holiday event on a Saturday and another on work_days[0]
        Event.objects.create(
            organization=self.org,
            title="Saturday Festival",
            start=saturdays[0],
            end=saturdays[0],
            is_holiday=True,
        )
        Event.objects.create(
            organization=self.org,
            title="Weekday Holiday",
            start=work_days[0],
            end=work_days[0],
            is_holiday=True,
        )
        # Duplicate holiday on same weekday should also be deduplicated
        Event.objects.create(
            organization=self.org,
            title="Duplicate Weekday Holiday",
            start=work_days[0],
            end=work_days[0],
            is_holiday=True,
        )

        self.assertEqual(count_saturdays(2083, 8), len(saturdays))
        self.assertEqual(count_holidays(self.org, 2083, 8), 1)

        # Employee checks in on saturdays[0] and work_days[0] (the holiday),
        # and is absent on work_days[1] and work_days[2], present on all other working days
        for wd in work_days[3:]:
            att = Attendance.objects.create(
                organization=self.org, employee=self.emp1, date=wd, is_remote=False
            )
            CheckInOut.objects.create(attendance=att, check_in=py_dt.time(9, 0), check_out=py_dt.time(17, 0))

        for extra_day in (saturdays[0], work_days[0]):
            att = Attendance.objects.create(
                organization=self.org, employee=self.emp1, date=extra_day, is_remote=False
            )
            CheckInOut.objects.create(attendance=att, check_in=py_dt.time(10, 0), check_out=py_dt.time(14, 0))

        # Even though employee checked in on a Saturday and a Public Holiday,
        # they still missed work_days[1] and work_days[2] (2 unpaid absences -> 28,000)
        gross = Salary.calculate_gross_salary(self.emp1, year=2083, month=8)
        self.assertEqual(gross, 28000)

        # Cross-month leave from 2083-08-28 to 2083-09-02
        casual = LeaveType.objects.create(organization=self.org, name="Casual", quota=12)
        LeaveRequest.objects.create(
            organization=self.org,
            employee=self.emp1,
            type=casual,
            from_date=nepali_datetime.date(2083, 8, 28),
            till_date=nepali_datetime.date(2083, 9, 2),
            subject="Cross Month Leave",
            is_paid=True,
            is_approved=True,
        )
        m8_paid = LeaveRequest.get_total_paid_leaves(self.emp1, 2083, 8)
        m9_paid = LeaveRequest.get_total_paid_leaves(self.emp1, 2083, 9)
        self.assertLessEqual(m8_paid, 2.0)
        self.assertGreater(m9_paid, 0.0)

    def test_remote_salary_zero_defaults_to_basic_rate(self):
        """
        When remote_salary is 0 (not separately configured), remote attendance days
        must be paid at the employee's standard basic_salary rate instead of 0.
        """
        import datetime as py_dt
        import nepali_datetime
        from attendance.models import Attendance, CheckInOut

        Salary.objects.filter(employee=self.emp1).update(basic_salary=30000, remote_salary=0)
        work_days = [
            nepali_datetime.date(2083, 8, d)
            for d in range(1, 30)
            if nepali_datetime.date(2083, 8, d).weekday() != 6
        ]
        for wd in work_days:
            att = Attendance.objects.create(
                organization=self.org, employee=self.emp1, date=wd, is_remote=True
            )
            CheckInOut.objects.create(attendance=att, check_in=py_dt.time(9, 0), check_out=py_dt.time(17, 0))

        gross = Salary.calculate_gross_salary(self.emp1, year=2083, month=8)
        self.assertEqual(gross, 30000)

    def test_transaction_creation_combines_base_tds_with_incentive_and_bonus_tds(self):
        """
        Verify Finding #1 fix: Creating a SalaryTransaction with incentive/bonus
        and no manual TDS override combines base salary progressive-band TDS with
        IncentiveTaxBand and BonusTaxBand TDS and saves transaction_tds.
        """
        from rest_framework import status
        from rest_framework.test import APIClient
        from fiscal_year.models import FiscalYear
        from salary_management.models import BonusTaxBand, IncentiveTaxBand, SalaryTransaction

        admin = Account.objects.create_superuser(
            email="tdsadmin@test.com", first_name="TDS", last_name="Admin", password="password123"
        )
        self.org.admin_users.add(admin)
        fy = FiscalYear.objects.create(organization=self.org, title="2083/84")

        # 1% base salary tax band -> 30,000 * 12 = 360,000 @ 1% = 3,600/yr = 300/month
        SalaryTaxBand.objects.create(
            organization=self.org, marital_status="single",
            min_salary=0, max_salary=500000, tax_percentage=1, order=1,
        )
        # 10% incentive tax band -> 10,000 @ 10% = 1,000
        IncentiveTaxBand.objects.create(
            organization=self.org, min_amount=0, max_amount=100000, tax_percentage=10, order=1,
        )
        # 15% bonus tax band -> 20,000 @ 15% = 3,000
        BonusTaxBand.objects.create(
            organization=self.org, min_amount=0, max_amount=100000, tax_percentage=15, order=1,
        )

        sal = Salary.objects.get(employee=self.emp1)
        client = APIClient()
        client.force_authenticate(user=admin)

        # Full month attendance via holidays_override=29 in Mangsir 2083 (29 days) -> Gross = 30,000
        res = client.post('/api/salary-management/transactions/organization/', {
            'salary': sal.id,
            'fiscal_year': fy.id,
            'date': '2083-08-29',
            'holidays': 29,
            'incentive': 10000,
            'bonus': 20000,
            'email_preference': 'none',
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)

        tx = SalaryTransaction.objects.get(id=res.data['id'])
        # Base TDS (300) + Incentive TDS (1000) + Bonus TDS (3000) = 4300
        self.assertEqual(tx.transaction_tds, 4300.0)
        # Net = (30,000 - 4,300) + 10,000 + 20,000 = 55,700
        self.assertEqual(tx.net_salary, 55700.0)
        # Total expense = Net (55,700) + TDS (4,300) = 60,000
        self.assertEqual(tx.total_expense, 60000.0)


class FinanceRoleAndAnalyticsTests(TestCase):
    def setUp(self):
        from rest_framework.test import APIClient
        from fiscal_year.models import FiscalYear
        from salary_management.models import FinanceAccess, SalaryTransaction
        import nepali_datetime

        self.client = APIClient()
        self.org = Organization.objects.create(name="OmWay Finance Org")
        self.other_org = Organization.objects.create(name="Other Org")

        self.dept_eng = Department.objects.create(organization=self.org, department_name="Engineering")
        self.dept_sales = Department.objects.create(organization=self.org, department_name="Sales")
        self.post_eng = Post.objects.create(department=self.dept_eng, title="Developer")
        self.post_sales = Post.objects.create(department=self.dept_sales, title="Executive")

        self.other_dept = Department.objects.create(organization=self.other_org, department_name="External")
        self.other_post = Post.objects.create(department=self.other_dept, title="Staff")

        self.admin_user = Account.objects.create_superuser(
            email="admin@finance.test", first_name="Super", last_name="Admin", password="password123"
        )
        self.org.admin_users.add(self.admin_user)

        self.finance_user = Account.objects.create_user(
            email="finance@finance.test", first_name="Maya", last_name="Finance", password="password123"
        )
        self.finance_user.is_finance = True
        self.finance_user.save()
        self.finance_access = FinanceAccess.objects.create(
            organization=self.org, user=self.finance_user, is_active=True
        )

        self.emp1_user = Account.objects.create_user(
            email="dev@finance.test", first_name="Dev", last_name="One", password="password123"
        )
        self.emp1 = Employee.objects.create(
            user=self.emp1_user, post=self.post_eng, date_of_joining=nepali_datetime.date(2081, 1, 1)
        )
        self.sal1 = Salary.objects.filter(employee=self.emp1).first()
        self.sal1.organization = self.org
        self.sal1.basic_salary = 50000
        self.sal1.ssf = 2000
        self.sal1.epf = 1500
        self.sal1.tds = 3000
        self.sal1.save()

        self.emp2_user = Account.objects.create_user(
            email="sales@finance.test", first_name="Sales", last_name="Two", password="password123"
        )
        self.emp2 = Employee.objects.create(
            user=self.emp2_user, post=self.post_sales, date_of_joining=nepali_datetime.date(2081, 1, 1)
        )
        self.sal2 = Salary.objects.filter(employee=self.emp2).first()
        self.sal2.organization = self.org
        self.sal2.basic_salary = 40000
        self.sal2.ssf = 1000
        self.sal2.epf = 1000
        self.sal2.tds = 2000
        self.sal2.save()

        self.other_emp_user = Account.objects.create_user(
            email="other@other.test", first_name="Other", last_name="Emp", password="password123"
        )
        self.other_emp = Employee.objects.create(
            user=self.other_emp_user, post=self.other_post, date_of_joining=nepali_datetime.date(2081, 1, 1)
        )

        self.fy_82 = FiscalYear.objects.create(organization=self.org, title="2082/83")
        self.fy_83 = FiscalYear.objects.create(organization=self.org, title="2083/84")

        # Transactions across 2082 and 2083 for Monthly + Yearly analytics
        self.tx_82 = SalaryTransaction.objects.create(
            organization=self.org, salary=self.sal1, fiscal_year=self.fy_82,
            date=nepali_datetime.date(2082, 12, 1), manual_net_salary=45000,
            transaction_tds=3000, transaction_ssf=2000, transaction_epf=1500,
            incentive=1000, bonus=0,
        )
        self.tx_83_m1_eng = SalaryTransaction.objects.create(
            organization=self.org, salary=self.sal1, fiscal_year=self.fy_83,
            date=nepali_datetime.date(2083, 1, 1), manual_net_salary=46000,
            transaction_tds=3500, transaction_ssf=2000, transaction_epf=1500,
            incentive=2000, bonus=1000,
        )
        self.tx_83_m2_sales = SalaryTransaction.objects.create(
            organization=self.org, salary=self.sal2, fiscal_year=self.fy_83,
            date=nepali_datetime.date(2083, 2, 1), manual_net_salary=36000,
            transaction_tds=2000, transaction_ssf=1000, transaction_epf=1000,
            incentive=0, bonus=500,
        )

    def test_admin_can_crud_finance_users_and_non_admins_blocked(self):
        from rest_framework import status
        # Admin creates Finance account
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.post('/api/salary-management/finance-users/', {
            'email': 'payroll2@finance.test',
            'first_name': 'Account',
            'last_name': 'Officer',
            'password': 'password123',
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        fin_id = res.data['id']
        self.assertEqual(res.data['email'], 'payroll2@finance.test')
        self.assertTrue(res.data['is_active'])

        # List
        list_res = self.client.get('/api/salary-management/finance-users/')
        self.assertEqual(list_res.status_code, status.HTTP_200_OK)
        items = list_res.data if isinstance(list_res.data, list) else list_res.data.get('results', [])
        self.assertEqual(len(items), 2)

        # Update
        patch_res = self.client.patch(f'/api/salary-management/finance-users/{fin_id}/', {
            'is_active': False, 'first_name': 'Senior'
        }, format='json')
        self.assertEqual(patch_res.status_code, status.HTTP_200_OK)
        self.assertFalse(patch_res.data['is_active'])
        self.assertEqual(patch_res.data['first_name'], 'Senior')

        # Delete deactivates standalone account
        del_res = self.client.delete(f'/api/salary-management/finance-users/{fin_id}/')
        self.assertEqual(del_res.status_code, status.HTTP_204_NO_CONTENT)
        acc = Account.objects.get(email='payroll2@finance.test')
        self.assertFalse(acc.is_finance)
        self.assertFalse(acc.is_active)

        # Finance user and Employee blocked from managing finance users
        for u in (self.finance_user, self.emp1_user):
            self.client.force_authenticate(user=u)
            self.assertEqual(self.client.get('/api/salary-management/finance-users/').status_code, status.HTTP_403_FORBIDDEN)
            self.assertEqual(
                self.client.post('/api/salary-management/finance-users/', {
                    'email': 'hack@finance.test', 'first_name': 'A', 'last_name': 'B', 'password': 'password123'
                }).status_code,
                status.HTTP_403_FORBIDDEN,
            )

    def test_finance_user_has_full_payroll_tax_fiscal_and_report_access(self):
        from rest_framework import status
        self.client.force_authenticate(user=self.finance_user)

        # Base salaries list & update
        self.assertEqual(self.client.get('/api/salary-management/salary/').status_code, status.HTTP_200_OK)
        upd = self.client.patch(f'/api/salary-management/salary/{self.sal1.id}/', {'basic_salary': 55000})
        self.assertEqual(upd.status_code, status.HTTP_200_OK)

        # Net salary calc for any org employee
        net = self.client.get(f'/api/salary-management/net-salary/{self.sal1.id}/?year=2083&month=1')
        self.assertEqual(net.status_code, status.HTTP_200_OK)

        # Org transactions list & employee transactions list
        self.assertEqual(self.client.get('/api/salary-management/transactions/organization/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.get(f'/api/salary-management/transactions/?employee={self.emp1.id}&year=2083').status_code, status.HTTP_200_OK)

        # Tax bands CRUD
        tb = self.client.post('/api/salary-management/tax-bands/salary/', {
            'marital_status': 'single', 'min_salary': 0, 'max_salary': 500000, 'tax_percentage': 1, 'order': 1
        })
        self.assertEqual(tb.status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.client.get('/api/salary-management/tax-bands/salary/').status_code, status.HTTP_200_OK)

        # Fiscal years CRUD
        fy = self.client.post('/api/fiscal-year/', {'title': '2084/85'})
        self.assertEqual(fy.status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.client.delete(f"/api/fiscal-year/{fy.data['id']}/").status_code, status.HTTP_204_NO_CONTENT)

        # CSV export
        csv_res = self.client.get('/api/salary-management/generate-report/?start_date=2083-01-01&end_date=2083-12-30')
        self.assertEqual(csv_res.status_code, status.HTTP_200_OK)

    def test_finance_user_has_readonly_org_scoped_employee_directory(self):
        from rest_framework import status
        self.client.force_authenticate(user=self.finance_user)

        # Can GET employees strictly in own org (not other_org)
        res = self.client.get('/api/organization/employees/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        items = res.data if isinstance(res.data, list) else res.data.get('results', [])
        ids = {e['id'] for e in items}
        self.assertIn(self.emp1.id, ids)
        self.assertIn(self.emp2.id, ids)
        self.assertNotIn(self.other_emp.id, ids)

        # Blocked on write / custom actions
        self.assertEqual(self.client.post('/api/organization/employees/', {}).status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(self.client.patch(f'/api/organization/employees/{self.emp1.id}/', {}).status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(self.client.delete(f'/api/organization/employees/{self.emp1.id}/').status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(
            self.client.post(f'/api/organization/employees/{self.emp1.id}/reset_password/', {'password': 'newpassword'}).status_code,
            status.HTTP_403_FORBIDDEN,
        )
        self.assertEqual(
            self.client.post(f'/api/organization/employees/{self.emp1.id}/toggle_active/').status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_deactivated_finance_and_employee_blocked_from_admin_salary_endpoints(self):
        from rest_framework import status
        # Deactivated finance user
        self.finance_access.is_active = False
        self.finance_access.save()
        self.client.force_authenticate(user=self.finance_user)
        self.assertEqual(self.client.get('/api/salary-management/transactions/organization/').status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(self.client.get('/api/salary-management/analytics/summary/').status_code, status.HTTP_403_FORBIDDEN)

        # Regular employee blocked from analytics, tax bands, fiscal year writes, transaction edits
        self.client.force_authenticate(user=self.emp1_user)
        self.assertEqual(self.client.get('/api/salary-management/analytics/summary/').status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(self.client.get('/api/salary-management/tax-bands/salary/').status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(self.client.post('/api/fiscal-year/', {'title': '2090/91'}).status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(
            self.client.patch(f'/api/salary-management/transactions/{self.tx_83_m1_eng.id}/', {'bonus': 99999}).status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_monthly_and_yearly_analytics_summary(self):
        from rest_framework import status
        self.client.force_authenticate(user=self.finance_user)

        res = self.client.get('/api/salary-management/analytics/summary/?year=2083')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.data

        self.assertEqual(data['selected_year'], 2083)
        self.assertEqual(len(data['monthly']), 12)
        self.assertEqual(data['available_years'], [2083, 2082])

        # Month 1 (Baishakh): emp1 net 46000, tds 3500
        m1 = data['monthly'][0]
        self.assertEqual(m1['label'], 'Baishakh')
        self.assertEqual(m1['net'], 46000.0)
        self.assertEqual(m1['tds'], 3500.0)
        self.assertEqual(m1['payout_count'], 1)

        # Month 2 (Jestha): emp2 net 36000, tds 2000
        m2 = data['monthly'][1]
        self.assertEqual(m2['net'], 36000.0)
        self.assertEqual(m2['tds'], 2000.0)

        # Yearly: 2082 and 2083 both aggregated
        yearly_map = {y['year']: y for y in data['yearly']}
        self.assertIn(2082, yearly_map)
        self.assertIn(2083, yearly_map)
        self.assertEqual(yearly_map[2082]['net'], 45000.0)
        self.assertEqual(yearly_map[2083]['net'], 82000.0)
        self.assertEqual(yearly_map[2083]['tds'], 5500.0)

        # KPIs for 2083 full year
        self.assertEqual(data['kpis']['total_net'], 82000.0)
        self.assertEqual(data['kpis']['total_tds'], 5500.0)
        self.assertEqual(data['kpis']['payout_count'], 2)

        # Department & Designation breakdown
        depts = {d['department']: d for d in data['by_department']}
        self.assertIn('Engineering', depts)
        self.assertIn('Sales', depts)
        self.assertEqual(depts['Engineering']['net'], 46000.0)
        self.assertEqual(depts['Sales']['net'], 36000.0)

        desigs = {d['designation']: d for d in data['by_designation']}
        self.assertIn('Developer', desigs)
        self.assertIn('Executive', desigs)
        self.assertEqual(desigs['Developer']['net'], 46000.0)
        self.assertEqual(desigs['Executive']['net'], 36000.0)

        # Month-scoped KPIs & designation breakdown (Month 1 only)
        res_m1 = self.client.get('/api/salary-management/analytics/summary/?year=2083&month=1')
        self.assertEqual(res_m1.status_code, status.HTTP_200_OK)
        self.assertEqual(res_m1.data['kpis']['total_net'], 46000.0)
        self.assertEqual(len(res_m1.data['by_designation']), 1)
        self.assertEqual(res_m1.data['by_designation'][0]['designation'], 'Developer')

    def test_me_endpoint_returns_finance_role(self):
        from rest_framework import status
        self.client.force_authenticate(user=self.finance_user)
        res = self.client.get('/api/auth/me/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['role'], 'finance')
        self.assertTrue(res.data['is_finance'])
        self.assertTrue(res.data['has_approved_policy'])
        self.assertEqual(res.data['organization_id'], self.org.id)


