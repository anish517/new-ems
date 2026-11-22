from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from authentication.models import Account
from organization.models import Organization, Department, Post, Employee, OrganizationSettings
from performance.models import PerformanceCategory, PerformanceReview, PerformanceReviewerAccess


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
        """When enable_daily_performance is False, employee is blocked with 403, but Admin retains access."""
        self.settings.enable_daily_performance = False
        self.settings.save()

        # Employee blocked
        self.client.force_authenticate(user=self.emp1_user)
        res = self.client.get('/api/performance/reviews/')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn("disabled", res.data.get('detail', '').lower())

        res_cat = self.client.get('/api/performance/categories/')
        self.assertEqual(res_cat.status_code, status.HTTP_403_FORBIDDEN)

        # Admin retains access
        self.client.force_authenticate(user=self.admin_user)
        res_admin = self.client.get('/api/performance/reviews/')
        self.assertEqual(res_admin.status_code, status.HTTP_200_OK)
        res_admin_cat = self.client.get('/api/performance/categories/')
        self.assertEqual(res_admin_cat.status_code, status.HTTP_200_OK)

    def test_performance_toggle_re_enabling_restores_access(self):
        """Toggling setting back to True immediately restores access."""
        self.settings.enable_daily_performance = False
        self.settings.save()

        self.client.force_authenticate(user=self.emp1_user)
        self.assertEqual(self.client.get('/api/performance/reviews/').status_code, status.HTTP_403_FORBIDDEN)

        self.settings.enable_daily_performance = True
        self.settings.save()

        self.assertEqual(self.client.get('/api/performance/reviews/').status_code, status.HTTP_200_OK)


class PerformanceReviewerFeatureTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.org = Organization.objects.create(name="OmWay Tech")
        self.dept = Department.objects.create(organization=self.org, department_name="Engineering")
        self.post = Post.objects.create(department=self.dept, title="Developer")

        self.admin_user = Account.objects.create_superuser(
            email="admin@omway.com", first_name="Super", last_name="Admin", password="password123"
        )
        self.org.admin_users.add(self.admin_user)

        self.emp1_user = Account.objects.create_user(
            email="alice@omway.com", first_name="Alice", last_name="Dev", password="password123"
        )
        self.emp1 = Employee.objects.create(user=self.emp1_user, post=self.post)

        self.emp2_user = Account.objects.create_user(
            email="bob@omway.com", first_name="Bob", last_name="QA", password="password123"
        )
        self.emp2 = Employee.objects.create(user=self.emp2_user, post=self.post)

        self.settings = OrganizationSettings.objects.create(
            organization=self.org,
            enable_daily_performance=True
        )

        self.cat_code = PerformanceCategory.objects.create(organization=self.org, name="Code Quality")
        self.cat_punct = PerformanceCategory.objects.create(organization=self.org, name="Punctuality")

        # Separate Performance Reviewer account linked to Alice (two-account setup)
        self.reviewer_user = Account.objects.create_user(
            email="alice.perf@omway.com", first_name="Alice", last_name="Reviewer", password="password123"
        )
        self.reviewer_user.is_performance_reviewer = True
        self.reviewer_user.save()
        self.reviewer_access = PerformanceReviewerAccess.objects.create(
            organization=self.org,
            reviewer=self.reviewer_user,
            linked_employee=self.emp1,
            is_active=True,
        )
        self.reviewer_access.categories.add(self.cat_code)

        # Admin-created reviews in both categories
        self.admin_review_code = PerformanceReview.objects.create(
            employee=self.emp2,
            reviewer=self.admin_user,
            category=self.cat_code,
            score=8,
            feedback="Solid code.",
        )
        self.admin_review_punct = PerformanceReview.objects.create(
            employee=self.emp2,
            reviewer=self.admin_user,
            category=self.cat_punct,
            score=9,
            feedback="Always on time.",
        )

    def test_admin_can_crud_performance_reviewers(self):
        self.client.force_authenticate(user=self.admin_user)
        # Create
        res = self.client.post('/api/performance/reviewers/', {
            'email': 'hr.perf@omway.com',
            'first_name': 'HR',
            'last_name': 'Reviewer',
            'password': 'secret123',
            'linked_employee': self.emp2.id,
            'category_ids': [self.cat_punct.id],
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        reviewer_access_id = res.data['id']
        self.assertEqual(res.data['email'], 'hr.perf@omway.com')
        self.assertEqual(res.data['linked_employee'], self.emp2.id)
        self.assertEqual([c['id'] for c in res.data['categories']], [self.cat_punct.id])

        # List
        list_res = self.client.get('/api/performance/reviewers/')
        self.assertEqual(list_res.status_code, status.HTTP_200_OK)
        items = list_res.data if isinstance(list_res.data, list) else list_res.data.get('results', [])
        self.assertEqual(len(items), 2)

        # Update categories & active status
        patch_res = self.client.patch(f'/api/performance/reviewers/{reviewer_access_id}/', {
            'category_ids': [self.cat_code.id, self.cat_punct.id],
            'is_active': False,
        }, format='json')
        self.assertEqual(patch_res.status_code, status.HTTP_200_OK)
        self.assertFalse(patch_res.data['is_active'])
        self.assertEqual(len(patch_res.data['categories']), 2)

        # Delete revokes access & deactivates standalone login
        del_res = self.client.delete(f'/api/performance/reviewers/{reviewer_access_id}/')
        self.assertEqual(del_res.status_code, status.HTTP_204_NO_CONTENT)
        acc = Account.objects.get(email='hr.perf@omway.com')
        self.assertFalse(acc.is_performance_reviewer)
        self.assertFalse(acc.is_active)

    def test_non_admin_blocked_from_managing_reviewers_and_categories(self):
        for user in (self.emp1_user, self.reviewer_user):
            self.client.force_authenticate(user=user)
            self.assertEqual(self.client.get('/api/performance/reviewers/').status_code, status.HTTP_403_FORBIDDEN)
            self.assertEqual(
                self.client.post('/api/performance/categories/', {'name': 'Hack'}).status_code,
                status.HTTP_403_FORBIDDEN,
            )

    def test_reviewer_can_score_only_assigned_categories_and_category_required(self):
        self.client.force_authenticate(user=self.reviewer_user)

        # Assigned category -> 201
        ok = self.client.post('/api/performance/reviews/', {
            'employee': self.emp2.id,
            'category': self.cat_code.id,
            'score': 9,
            'feedback': 'Clean PRs.',
        })
        self.assertEqual(ok.status_code, status.HTTP_201_CREATED)

        # Unassigned category -> 403
        bad_cat = self.client.post('/api/performance/reviews/', {
            'employee': self.emp2.id,
            'category': self.cat_punct.id,
            'score': 7,
            'feedback': 'Punctual.',
        })
        self.assertEqual(bad_cat.status_code, status.HTTP_403_FORBIDDEN)

        # Missing category -> 400
        no_cat = self.client.post('/api/performance/reviews/', {
            'employee': self.emp2.id,
            'score': 7,
            'feedback': 'No category.',
        })
        self.assertEqual(no_cat.status_code, status.HTTP_400_BAD_REQUEST)

    def test_self_review_blocked_for_two_account_and_single_account(self):
        # Two-account setup: reviewer_user is linked_employee = emp1
        self.client.force_authenticate(user=self.reviewer_user)
        res = self.client.post('/api/performance/reviews/', {
            'employee': self.emp1.id,
            'category': self.cat_code.id,
            'score': 10,
            'feedback': 'I am great.',
        })
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # Single-account setup: admin who also has an Employee record
        admin_emp = Employee.objects.create(user=self.admin_user, post=self.post)
        self.client.force_authenticate(user=self.admin_user)
        res_self = self.client.post('/api/performance/reviews/', {
            'employee': admin_emp.id,
            'category': self.cat_code.id,
            'score': 10,
        })
        self.assertEqual(res_self.status_code, status.HTTP_403_FORBIDDEN)

    def test_my_categories_and_reviewable_employees_scoping(self):
        self.client.force_authenticate(user=self.reviewer_user)

        cats_res = self.client.get('/api/performance/my-categories/')
        self.assertEqual(cats_res.status_code, status.HTTP_200_OK)
        self.assertEqual([c['id'] for c in cats_res.data], [self.cat_code.id])

        emps_res = self.client.get('/api/performance/reviewable-employees/')
        self.assertEqual(emps_res.status_code, status.HTTP_200_OK)
        emp_ids = [e['id'] for e in emps_res.data]
        self.assertIn(self.emp2.id, emp_ids)
        # linked_employee (emp1) is excluded!
        self.assertNotIn(self.emp1.id, emp_ids)

        # Regular employee blocked from both endpoints
        self.client.force_authenticate(user=self.emp2_user)
        self.assertEqual(self.client.get('/api/performance/my-categories/').status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(self.client.get('/api/performance/reviewable-employees/').status_code, status.HTTP_403_FORBIDDEN)

    def test_reviewer_visibility_and_edit_delete_ownership(self):
        self.client.force_authenticate(user=self.reviewer_user)

        # Reviewer creates their own review in Code Quality
        created = self.client.post('/api/performance/reviews/', {
            'employee': self.emp2.id,
            'category': self.cat_code.id,
            'score': 7,
            'feedback': 'Good.',
        })
        self.assertEqual(created.status_code, status.HTTP_201_CREATED)
        own_id = created.data['id']

        # Reviewer sees only Code Quality reviews (own + admin's Code Quality), NOT Punctuality
        list_res = self.client.get('/api/performance/reviews/')
        items = list_res.data if isinstance(list_res.data, list) else list_res.data.get('results', [])
        ids = {r['id'] for r in items}
        self.assertIn(own_id, ids)
        self.assertIn(self.admin_review_code.id, ids)
        self.assertNotIn(self.admin_review_punct.id, ids)

        # Can edit own review, CANNOT edit or delete admin's review
        self.assertEqual(
            self.client.patch(f'/api/performance/reviews/{own_id}/', {'score': 8}).status_code,
            status.HTTP_200_OK,
        )
        self.assertEqual(
            self.client.patch(f'/api/performance/reviews/{self.admin_review_code.id}/', {'score': 2}).status_code,
            status.HTTP_403_FORBIDDEN,
        )
        self.assertEqual(
            self.client.delete(f'/api/performance/reviews/{self.admin_review_code.id}/').status_code,
            status.HTTP_403_FORBIDDEN,
        )
        # Can delete own review
        self.assertEqual(
            self.client.delete(f'/api/performance/reviews/{own_id}/').status_code,
            status.HTTP_204_NO_CONTENT,
        )

    def test_deactivated_reviewer_blocked(self):
        self.reviewer_access.is_active = False
        self.reviewer_access.save()
        self.client.force_authenticate(user=self.reviewer_user)
        res = self.client.post('/api/performance/reviews/', {
            'employee': self.emp2.id,
            'category': self.cat_code.id,
            'score': 8,
        })
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_employee_blocked_from_creating_editing_deleting_and_other_replies(self):
        self.client.force_authenticate(user=self.emp2_user)
        # Cannot POST review
        self.assertEqual(
            self.client.post('/api/performance/reviews/', {
                'employee': self.emp1.id, 'category': self.cat_code.id, 'score': 5
            }).status_code,
            status.HTTP_403_FORBIDDEN,
        )
        # Cannot PATCH or DELETE own review
        self.assertEqual(
            self.client.patch(f'/api/performance/reviews/{self.admin_review_code.id}/', {'score': 10}).status_code,
            status.HTTP_403_FORBIDDEN,
        )
        self.assertEqual(
            self.client.delete(f'/api/performance/reviews/{self.admin_review_code.id}/').status_code,
            status.HTTP_403_FORBIDDEN,
        )
        # Another employee (emp1) cannot reply to emp2's review
        self.client.force_authenticate(user=self.emp1_user)
        self.assertEqual(
            self.client.patch(f'/api/performance/reviews/{self.admin_review_code.id}/reply/', {'reply': 'Hi'}).status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_reviewer_retains_access_when_daily_performance_disabled(self):
        self.settings.enable_daily_performance = False
        self.settings.save()
        self.client.force_authenticate(user=self.reviewer_user)
        self.assertEqual(self.client.get('/api/performance/reviews/').status_code, status.HTTP_200_OK)
        self.assertEqual(self.client.get('/api/performance/my-categories/').status_code, status.HTTP_200_OK)

    def test_reviewer_identity_hidden_from_employees_only(self):
        # Employee GET -> reviewer & reviewer_name are None
        self.client.force_authenticate(user=self.emp2_user)
        emp_res = self.client.get('/api/performance/reviews/')
        items = emp_res.data if isinstance(emp_res.data, list) else emp_res.data.get('results', [])
        self.assertGreater(len(items), 0)
        for item in items:
            self.assertIsNone(item['reviewer'])
            self.assertIsNone(item['reviewer_name'])

        # Employee reply response -> also hides reviewer & reviewer_name
        reply_res = self.client.patch(
            f'/api/performance/reviews/{self.admin_review_code.id}/reply/',
            {'reply': 'Noted, thanks!'},
        )
        self.assertEqual(reply_res.status_code, status.HTTP_200_OK)
        self.assertIsNone(reply_res.data['reviewer'])
        self.assertIsNone(reply_res.data['reviewer_name'])

        # Admin GET -> sees reviewer & reviewer_name
        self.client.force_authenticate(user=self.admin_user)
        admin_res = self.client.get('/api/performance/reviews/')
        admin_items = admin_res.data if isinstance(admin_res.data, list) else admin_res.data.get('results', [])
        self.assertIsNotNone(admin_items[0]['reviewer'])
        self.assertEqual(admin_items[0]['reviewer_name'], 'Super Admin')

        # Reviewer GET -> sees reviewer & reviewer_name
        self.client.force_authenticate(user=self.reviewer_user)
        rev_res = self.client.get('/api/performance/reviews/')
        rev_items = rev_res.data if isinstance(rev_res.data, list) else rev_res.data.get('results', [])
        self.assertIsNotNone(rev_items[0]['reviewer'])
        self.assertEqual(rev_items[0]['reviewer_name'], 'Super Admin')

    def test_me_endpoint_returns_performance_reviewer_role_and_categories(self):
        self.client.force_authenticate(user=self.reviewer_user)
        res = self.client.get('/api/auth/me/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['role'], 'performance_reviewer')
        self.assertTrue(res.data['is_performance_reviewer'])
        self.assertEqual(res.data['performance_category_ids'], [self.cat_code.id])
        self.assertTrue(res.data['has_approved_policy'])
        self.assertEqual(res.data['organization_id'], self.org.id)
