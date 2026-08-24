"""
Regression tests for the API authorization gates.

These cover three fail-open holes where an endpoint either ran as AllowAny with
no authorization check, or resolved no organization and then widened its
queryset to every tenant instead of refusing. Each test asserts both halves:
that an ordinary employee is refused, and that a legitimate admin is not --
an over-tight gate would break payroll and leave approval in production.
"""
from django.test import TestCase
from nepali_datetime import date as nepali_date
from rest_framework.test import APIClient

from authentication.models import Account
from organization.models import Organization, Department, Post, Employee
from leave_management.models import LeaveType, LeaveRequest

EXPORT_URL = '/api/organization/employees/export-csv/'
SALARY_REPORT_URL = '/api/salary/generate-report/'


class AuthorizationRegressionTests(TestCase):
    def setUp(self):
        self.org = Organization.objects.create(name="Org A")
        self.dept = Department.objects.create(
            organization=self.org, department_name="Engineering")
        self.post = Post.objects.create(department=self.dept, title="Developer")

        # An ordinary employee: has no row in Organization.admin_users, which is
        # what `user.organization` reverses to.
        self.employee_user = Account.objects.create(
            email="employee@test.com", first_name="Plain", last_name="Employee")
        self.employee = Employee.objects.create(
            user=self.employee_user, post=self.post)

        # An admin of the same organization.
        self.admin_user = Account.objects.create(
            email="admin@test.com", first_name="Org", last_name="Admin")
        self.admin_employee = Employee.objects.create(
            user=self.admin_user, post=self.post)
        self.org.admin_users.add(self.admin_user)

        # An admin of a different organization, for the cross-tenant check.
        self.other_org = Organization.objects.create(name="Org B")
        self.other_admin = Account.objects.create(
            email="other@test.com", first_name="Other", last_name="Admin")
        self.other_org.admin_users.add(self.other_admin)

        self.leave_type = LeaveType.objects.create(
            organization=self.org, name="Sick Leave", quota=12)
        self.leave = LeaveRequest.objects.create(
            organization=self.org, employee=self.employee, type=self.leave_type,
            from_date=nepali_date(2080, 1, 3), till_date=nepali_date(2080, 1, 3),
            subject="Fever")

        self.client = APIClient()

    # ---------------------------------------------------------------- export

    def test_employee_cannot_export_employee_directory(self):
        """The directory CSV carries PAN and bank details -- admin/HR only."""
        self.client.force_authenticate(user=self.employee_user)
        self.assertEqual(self.client.get(EXPORT_URL).status_code, 403)

    def test_admin_can_still_export_employee_directory(self):
        self.client.force_authenticate(user=self.admin_user)
        self.assertEqual(self.client.get(EXPORT_URL).status_code, 200)

    def test_export_does_not_fall_back_to_all_tenants(self):
        """
        An admin whose organization cannot be resolved must be refused, not
        served Employee.objects.all(). Previously this leaked every tenant.
        """
        orphan = Account.objects.create(
            email="orphan@test.com", first_name="No", last_name="Org",
            is_staff=True)
        self.client.force_authenticate(user=orphan)
        self.assertEqual(self.client.get(EXPORT_URL).status_code, 400)

    # ---------------------------------------------------------------- salary

    def test_employee_cannot_generate_salary_report(self):
        self.client.force_authenticate(user=self.employee_user)
        self.assertEqual(self.client.get(SALARY_REPORT_URL).status_code, 403)

    def test_admin_can_reach_salary_report(self):
        self.client.force_authenticate(user=self.admin_user)
        self.assertNotEqual(self.client.get(SALARY_REPORT_URL).status_code, 403)

    # ----------------------------------------------------------------- leave

    def _patch_leave(self, pk, payload):
        return self.client.patch(
            '/api/leave-tracker/update/%d/' % pk, payload, format='json')

    def test_employee_cannot_approve_own_leave(self):
        self.client.force_authenticate(user=self.employee_user)
        response = self._patch_leave(self.leave.pk, {'action': 'final_approve'})
        self.assertEqual(response.status_code, 403)
        self.leave.refresh_from_db()
        self.assertFalse(self.leave.is_approved)

    def test_employee_cannot_approve_via_bare_flag(self):
        """The gate must cover the serializer path, not just `action`."""
        self.client.force_authenticate(user=self.employee_user)
        response = self._patch_leave(self.leave.pk, {'is_approved': True})
        self.assertEqual(response.status_code, 403)
        self.leave.refresh_from_db()
        self.assertFalse(self.leave.is_approved)

    def test_admin_can_approve_leave(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self._patch_leave(self.leave.pk, {'action': 'final_approve'})
        self.assertEqual(response.status_code, 200)
        self.leave.refresh_from_db()
        self.assertTrue(self.leave.is_approved)

    def test_admin_cannot_approve_another_orgs_leave(self):
        self.client.force_authenticate(user=self.other_admin)
        response = self._patch_leave(self.leave.pk, {'action': 'final_approve'})
        self.assertEqual(response.status_code, 403)
        self.leave.refresh_from_db()
        self.assertFalse(self.leave.is_approved)

    def test_employee_edit_of_own_leave_is_not_blocked(self):
        """
        The gate keys on decision fields only. A plain edit -- including one
        echoing back is_approved: false -- must not be swept up as an approval.
        """
        self.client.force_authenticate(user=self.employee_user)
        response = self._patch_leave(
            self.leave.pk, {'subject': 'Fever, updated', 'is_approved': False})
        self.assertNotEqual(response.status_code, 403)
