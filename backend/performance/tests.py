from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from authentication.models import Account
from organization.models import Organization, Department, Post, Employee, OrganizationSettings
from performance.models import PerformanceCategory, PerformanceReview


class PerformanceSettingTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.org = Organization.objects.create(name="Test Org")
        self.dept = Department.objects.create(organization=self.org, department_name="Engineering")
        self.post = Post.objects.create(department=self.dept, title="Engineer")

        # Admin user
        self.admin_user = Account.objects.create(
            email="admin@test.com", first_name="Admin", last_name="User", is_superuser=True
        )
        self.org.admin_users.add(self.admin_user)

        # Employee 1
        self.emp1_user = Account.objects.create(
            email="emp1@test.com", first_name="Alice", last_name="Dev"
        )
        self.emp1 = Employee.objects.create(user=self.emp1_user, post=self.post)

        # Employee 2
        self.emp2_user = Account.objects.create(
            email="emp2@test.com", first_name="Bob", last_name="QA"
        )
        self.emp2 = Employee.objects.create(user=self.emp2_user, post=self.post)

        # Settings
        self.settings = OrganizationSettings.objects.create(
            organization=self.org,
            enable_daily_performance=True
        )

        # Category
        self.cat = PerformanceCategory.objects.create(
            organization=self.org,
            name="Code Quality"
        )

        # Reviews
        self.review1 = PerformanceReview.objects.create(
            employee=self.emp1,
            reviewer=self.admin_user,
            category=self.cat,
            score=9,
            feedback="Excellent code structure and modularity.",
            suggestion="Keep writing clean tests."
        )
        self.review2 = PerformanceReview.objects.create(
            employee=self.emp2,
            reviewer=self.admin_user,
            category=self.cat,
            score=7,
            feedback="Good test coverage.",
            suggestion="Improve automation pipeline speed."
        )

    def test_performance_enabled_allows_viewing_own_reviews(self):
        """Employee only sees their own review and score."""
        self.client.force_authenticate(user=self.emp1_user)
        res = self.client.get('/api/performance/reviews/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        results = res.data if isinstance(res.data, list) else res.data.get('results', [])
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['employee'], self.emp1.id)
        self.assertEqual(results[0]['score'], 9)

    def test_admin_views_all_employee_reviews_and_scores(self):
        """Admin sees all employee reviews and performance scores across the organization."""
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.get('/api/performance/reviews/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        results = res.data if isinstance(res.data, list) else res.data.get('results', [])
        self.assertEqual(len(results), 2)
        scores = [r['score'] for r in results]
        self.assertIn(9, scores)
        self.assertIn(7, scores)

    def test_admin_can_filter_reviews_by_employee(self):
        """Admin can filter performance reviews by specific employee."""
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.get(f'/api/performance/reviews/?employee={self.emp2.id}')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        results = res.data if isinstance(res.data, list) else res.data.get('results', [])
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['employee'], self.emp2.id)
        self.assertEqual(results[0]['score'], 7)

    def test_admin_can_create_review(self):
        """Admin can submit a new performance review."""
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.post('/api/performance/reviews/', {
            'employee': self.emp1.id,
            'category': self.cat.id,
            'score': 10,
            'feedback': 'Outstanding initiative on refactor.',
            'suggestion': 'None.'
        })
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(PerformanceReview.objects.filter(employee=self.emp1).count(), 2)

    def test_employee_can_reply_to_review(self):
        """Employee can submit a reply to a review."""
        self.client.force_authenticate(user=self.emp1_user)
        res = self.client.patch(f'/api/performance/reviews/{self.review1.id}/reply/', {
            'reply': 'Thank you for the constructive feedback!'
        })
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.review1.refresh_from_db()
        self.assertEqual(self.review1.reply, 'Thank you for the constructive feedback!')

    def test_admin_category_management_and_non_admin_blocked(self):
        """Admin can create category, employee is blocked with 403."""
        self.client.force_authenticate(user=self.emp1_user)
        res = self.client.post('/api/performance/categories/', {'name': 'Unauthorized Category'})
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        self.client.force_authenticate(user=self.admin_user)
        res = self.client.post('/api/performance/categories/', {'name': 'Leadership'})
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)

    def test_performance_disabled_blocks_all_access(self):
        """When enable_daily_performance is False, reviews and categories return 403 Forbidden."""
        self.settings.enable_daily_performance = False
        self.settings.save()

        # Employee blocked
        self.client.force_authenticate(user=self.emp1_user)
        res = self.client.get('/api/performance/reviews/')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn("disabled", res.data.get('detail', '').lower())

        res_cat = self.client.get('/api/performance/categories/')
        self.assertEqual(res_cat.status_code, status.HTTP_403_FORBIDDEN)

    def test_performance_toggle_re_enabling_restores_access(self):
        """Toggling setting back to True immediately restores access."""
        self.settings.enable_daily_performance = False
        self.settings.save()

        self.client.force_authenticate(user=self.emp1_user)
        self.assertEqual(self.client.get('/api/performance/reviews/').status_code, status.HTTP_403_FORBIDDEN)

        self.settings.enable_daily_performance = True
        self.settings.save()

        self.assertEqual(self.client.get('/api/performance/reviews/').status_code, status.HTTP_200_OK)
