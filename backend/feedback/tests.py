from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from authentication.models import Account
from organization.models import Organization, Department, Post, Employee
from feedback.models import ComplainCategory, Complain, ComplainReply


class FeedbackPermissionTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.org = Organization.objects.create(name="Test Org")
        self.dept = Department.objects.create(organization=self.org, department_name="HR")
        self.post = Post.objects.create(department=self.dept, title="Staff")

        # Admin user
        self.admin_user = Account.objects.create(
            email="admin@test.com", first_name="Admin", last_name="User", is_superuser=True
        )
        self.org.admin_users.add(self.admin_user)

        # Employee user
        self.emp_user = Account.objects.create(
            email="employee@test.com", first_name="Staff", last_name="Member"
        )
        self.emp = Employee.objects.create(user=self.emp_user, post=self.post)

        self.category = ComplainCategory.objects.create(
            organization=self.org,
            title="Workplace Environment"
        )

        self.complain = Complain.objects.create(
            organization=self.org,
            owner=self.emp,
            title="AC not working",
            category=self.category,
            description="The 3rd floor AC needs repair.",
            status="pending"
        )

    def test_employee_can_submit_complaint(self):
        """Employee can successfully submit a new complaint."""
        self.client.force_authenticate(user=self.emp_user)
        res = self.client.post('/api/feedback/', {
            'title': 'Cafeteria food quality',
            'category': self.category.id,
            'description': 'Please improve hygiene.',
            'visibility': 'identified'
        })
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Complain.objects.count(), 2)

    def test_admin_cannot_submit_complaint(self):
        """Admin is strictly blocked from creating a complaint (employee-only action)."""
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.post('/api/feedback/', {
            'title': 'Admin Grievance',
            'category': self.category.id,
            'description': 'Trying to post as admin.',
            'visibility': 'anonymous'
        })
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn("cannot submit feedback complaints", str(res.data))
        self.assertEqual(Complain.objects.count(), 1)

    def test_admin_can_view_all_complaints(self):
        """Admin can view complaints for the organization."""
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.get('/api/feedback/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        results = res.data if isinstance(res.data, list) else res.data.get('results', [])
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['title'], "AC not working")

    def test_admin_can_update_and_resolve_complaint(self):
        """Admin can change complaint status to resolved."""
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.patch(f'/api/feedback/{self.complain.id}/', {
            'status': 'resolved'
        })
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.complain.refresh_from_db()
        self.assertEqual(self.complain.status, 'resolved')

    def test_admin_can_reply_to_complaint(self):
        """Admin can reply to an employee complaint."""
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.post(f'/api/feedback/{self.complain.id}/reply/', {
            'message': 'We have contacted the technician.'
        })
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(ComplainReply.objects.filter(complain=self.complain).count(), 1)

    def test_admin_can_delete_complaint(self):
        """Admin can delete a complaint."""
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.delete(f'/api/feedback/{self.complain.id}/')
        self.assertEqual(res.status_code, status.HTTP_204_NO_CONTENT)
        self.assertEqual(Complain.objects.count(), 0)
