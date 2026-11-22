import nepali_datetime
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from authentication.models import Account
from notification.models import Notification
from organization.models import Department, Employee, Organization, Post
from task_management.models import Project, ProjectAssignment, Task, TaskProgressReport
from task_management.utils import get_employee_task_summary, get_organization_task_summary


class TrelloTaskBoardTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.today = nepali_datetime.date.today()

        # Primary organization
        self.org = Organization.objects.create(name="OmWay Tech")
        self.dept = Department.objects.create(organization=self.org, department_name="Engineering")
        self.post = Post.objects.create(department=self.dept, title="Software Engineer")

        # Secondary organization (isolation checks)
        self.other_org = Organization.objects.create(name="Other Corp")
        self.other_dept = Department.objects.create(organization=self.other_org, department_name="Ops")
        self.other_post = Post.objects.create(department=self.other_dept, title="Analyst")

        # Admin user
        self.admin_user = Account.objects.create(
            email="admin@omway.com", first_name="Super", last_name="Admin", is_superuser=True
        )
        self.org.admin_users.add(self.admin_user)

        # Standalone finance user (no Employee record)
        self.finance_user = Account.objects.create(
            email="finance@omway.com", first_name="Fin", last_name="Lead", is_finance=True
        )

        # Employees in primary org
        self.emp1_user = Account.objects.create(
            email="alice@omway.com", first_name="Alice", last_name="Dev"
        )
        self.emp1 = Employee.objects.create(user=self.emp1_user, post=self.post)

        self.emp2_user = Account.objects.create(
            email="bob@omway.com", first_name="Bob", last_name="QA"
        )
        self.emp2 = Employee.objects.create(user=self.emp2_user, post=self.post)

        # Employee in other org
        self.other_user = Account.objects.create(
            email="eve@other.com", first_name="Eve", last_name="Other"
        )
        self.other_emp = Employee.objects.create(user=self.other_user, post=self.other_post)

        # Projects
        self.assigned_project = Project.objects.create(
            organization=self.org,
            title="EMS Mobile App",
            created_at=self.today,
            updated_at=self.today,
        )
        ProjectAssignment.objects.create(
            project=self.assigned_project, employee=self.emp1, role="senior"
        )

        self.unassigned_project = Project.objects.create(
            organization=self.org,
            title="Secret Infra Upgrade",
            created_at=self.today,
            updated_at=self.today,
        )
        ProjectAssignment.objects.create(
            project=self.unassigned_project, employee=self.emp2, role="junior"
        )

        # Existing Admin-assigned project task for emp1
        self.admin_task = Task.objects.create(
            project=self.assigned_project,
            assigned_to=self.emp1,
            created_by=None,
            title="Build Push Notifications",
            status="to-do",
            priority="high",
            is_personal=False,
            created_at=self.today,
            updated_at=self.today,
            planned_start_date=self.today,
            planned_end_date=self.today,
        )

    def test_employee_creates_personal_card_without_project(self):
        self.client.force_authenticate(user=self.emp1_user)
        res = self.client.post(
            "/api/task-management/tasks/",
            {
                "title": "Refactor local caching",
                "description": "Clean up stale keys",
                "priority": "medium",
                "status": "to-do",
            },
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(res.data["is_personal"])
        self.assertIsNone(res.data["project"]["id"])
        self.assertEqual(res.data["assigned_to"]["id"], self.emp1.id)
        self.assertEqual(res.data["created_by"]["id"], self.emp1.id)
        self.assertTrue(res.data["can_edit"])
        self.assertTrue(res.data["can_delete"])

        # Visible in GET list and GET detail
        task_id = res.data["id"]
        list_res = self.client.get("/api/task-management/tasks/")
        self.assertEqual(list_res.status_code, status.HTTP_200_OK)
        list_items = list_res.data["results"] if isinstance(list_res.data, dict) else list_res.data
        ids = [t["id"] for t in list_items]
        self.assertIn(task_id, ids)
        self.assertIn(self.admin_task.id, ids)

        detail_res = self.client.get(f"/api/task-management/tasks/{task_id}/")
        self.assertEqual(detail_res.status_code, status.HTTP_200_OK)
        self.assertEqual(detail_res.data["title"], "Refactor local caching")

    def test_employee_creates_task_on_assigned_project(self):
        self.client.force_authenticate(user=self.emp1_user)
        res = self.client.post(
            "/api/task-management/tasks/",
            {
                "title": "Write Flutter widget tests",
                "project": self.assigned_project.id,
                "priority": "high",
                "status": "in-progress",
                "rating": 10,  # Should be ignored for employee
            },
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertFalse(res.data["is_personal"])
        self.assertEqual(res.data["project"]["id"], self.assigned_project.id)
        self.assertEqual(res.data["assigned_to"]["id"], self.emp1.id)
        self.assertIsNone(res.data["rating"])
        self.assertFalse(res.data["can_edit"])
        self.assertFalse(res.data["can_delete"])

    def test_employee_cannot_create_task_on_unassigned_project(self):
        self.client.force_authenticate(user=self.emp1_user)
        res = self.client.post(
            "/api/task-management/tasks/",
            {
                "title": "Sneaky task",
                "project": self.unassigned_project.id,
            },
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_employee_cannot_impersonate_another_assignee(self):
        self.client.force_authenticate(user=self.emp1_user)
        res = self.client.post(
            "/api/task-management/tasks/",
            {
                "title": "Assigned to Bob?",
                "assigned_to": self.emp2.id,
            },
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        # Backend enforces self-assignment
        self.assertEqual(res.data["assigned_to"]["id"], self.emp1.id)

    def test_move_card_across_columns_and_positions(self):
        self.client.force_authenticate(user=self.emp1_user)
        create_res = self.client.post(
            "/api/task-management/tasks/",
            {"title": "Trello Card 1", "status": "to-do"},
            format="json",
        )
        card_id = create_res.data["id"]

        move_res = self.client.patch(
            f"/api/task-management/tasks/{card_id}/move/",
            {"status": "in-progress", "position": 0},
            format="json",
        )
        self.assertEqual(move_res.status_code, status.HTTP_200_OK)
        self.assertEqual(move_res.data["status"], "in-progress")
        self.assertEqual(move_res.data["position"], 0)

        done_res = self.client.patch(
            f"/api/task-management/tasks/{card_id}/move/",
            {"status": "done"},
            format="json",
        )
        self.assertEqual(done_res.status_code, status.HTTP_200_OK)
        self.assertEqual(done_res.data["status"], "done")

        # Invalid status rejected
        bad_res = self.client.patch(
            f"/api/task-management/tasks/{card_id}/move/",
            {"status": "archived"},
            format="json",
        )
        self.assertEqual(bad_res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_progress_logs_work_on_personal_card(self):
        self.client.force_authenticate(user=self.emp1_user)
        card_res = self.client.post(
            "/api/task-management/tasks/",
            {"title": "Self-tracked API audit", "task_type": "hourly"},
            format="json",
        )
        card_id = card_res.data["id"]

        log_res = self.client.post(
            f"/api/task-management/tasks/{card_id}/progress/",
            {"description": "Audited 12 endpoints", "hours_worked": "2.5"},
            format="json",
        )
        self.assertEqual(log_res.status_code, status.HTTP_201_CREATED)
        self.assertIsNone(log_res.data["earned_amount"])

        list_logs = self.client.get(f"/api/task-management/tasks/{card_id}/progress/")
        self.assertEqual(list_logs.status_code, status.HTTP_200_OK)
        self.assertEqual(len(list_logs.data), 1)

        # Progress count updated on task payload
        task_res = self.client.get(f"/api/task-management/tasks/{card_id}/")
        self.assertEqual(task_res.data["progress_count"], 1)

        # Employee still cannot directly delete progress reports
        report_id = log_res.data["id"]
        del_report = self.client.delete(f"/api/task-management/progress/{report_id}/")
        self.assertEqual(del_report.status_code, status.HTTP_403_FORBIDDEN)

    def test_employee_edit_and_delete_permissions(self):
        self.client.force_authenticate(user=self.emp1_user)
        personal_res = self.client.post(
            "/api/task-management/tasks/",
            {"title": "Personal Draft", "priority": "low"},
            format="json",
        )
        personal_id = personal_res.data["id"]

        # Employee CAN edit own personal card
        edit_res = self.client.patch(
            f"/api/task-management/tasks/{personal_id}/",
            {"title": "Personal Final", "priority": "high"},
            format="json",
        )
        self.assertEqual(edit_res.status_code, status.HTTP_200_OK)
        self.assertEqual(edit_res.data["title"], "Personal Final")
        self.assertEqual(edit_res.data["priority"], "high")

        # Employee CANNOT reassign own personal card to someone else
        reassign_res = self.client.patch(
            f"/api/task-management/tasks/{personal_id}/",
            {"assigned_to": self.emp2.id},
            format="json",
        )
        self.assertEqual(reassign_res.status_code, status.HTTP_403_FORBIDDEN)

        # Employee CAN update status of admin-assigned project task
        status_res = self.client.patch(
            f"/api/task-management/tasks/{self.admin_task.id}/",
            {"status": "in-progress"},
            format="json",
        )
        self.assertEqual(status_res.status_code, status.HTTP_200_OK)

        # Employee CANNOT edit title or delete admin-assigned project task
        tamper_res = self.client.patch(
            f"/api/task-management/tasks/{self.admin_task.id}/",
            {"title": "Hacked title"},
            format="json",
        )
        self.assertEqual(tamper_res.status_code, status.HTTP_403_FORBIDDEN)

        del_admin_task = self.client.delete(f"/api/task-management/tasks/{self.admin_task.id}/")
        self.assertEqual(del_admin_task.status_code, status.HTTP_403_FORBIDDEN)

        # Employee CAN delete own personal card
        del_personal = self.client.delete(f"/api/task-management/tasks/{personal_id}/")
        self.assertEqual(del_personal.status_code, status.HTTP_204_NO_CONTENT)

    def test_other_employee_and_cross_org_isolation(self):
        self.client.force_authenticate(user=self.emp1_user)
        card_res = self.client.post(
            "/api/task-management/tasks/",
            {"title": "Alice Private Card"},
            format="json",
        )
        card_id = card_res.data["id"]

        # Bob (same org) cannot view, move, log progress on, or delete Alice's card
        self.client.force_authenticate(user=self.emp2_user)
        self.assertEqual(self.client.get(f"/api/task-management/tasks/{card_id}/").status_code, 404)
        self.assertEqual(
            self.client.patch(f"/api/task-management/tasks/{card_id}/move/", {"status": "done"}, format="json").status_code,
            404,
        )
        self.assertEqual(
            self.client.post(f"/api/task-management/tasks/{card_id}/progress/", {"description": "Hi"}, format="json").status_code,
            404,
        )
        self.assertEqual(self.client.delete(f"/api/task-management/tasks/{card_id}/").status_code, 404)

        # Eve (other org) cannot view Alice's card
        self.client.force_authenticate(user=self.other_user)
        self.assertEqual(self.client.get(f"/api/task-management/tasks/{card_id}/").status_code, 404)

    def test_admin_sees_both_and_can_filter_by_scope(self):
        self.client.force_authenticate(user=self.emp1_user)
        personal_res = self.client.post(
            "/api/task-management/tasks/",
            {"title": "Alice Personal Card"},
            format="json",
        )
        personal_id = personal_res.data["id"]

        self.client.force_authenticate(user=self.admin_user)
        all_res = self.client.get("/api/task-management/tasks/")
        all_items = all_res.data["results"] if isinstance(all_res.data, dict) else all_res.data
        all_ids = [t["id"] for t in all_items]
        self.assertIn(self.admin_task.id, all_ids)
        self.assertIn(personal_id, all_ids)

        proj_res = self.client.get("/api/task-management/tasks/?scope=project")
        proj_items = proj_res.data["results"] if isinstance(proj_res.data, dict) else proj_res.data
        proj_ids = [t["id"] for t in proj_items]
        self.assertIn(self.admin_task.id, proj_ids)
        self.assertNotIn(personal_id, proj_ids)

        pers_res = self.client.get("/api/task-management/tasks/?scope=personal")
        pers_items = pers_res.data["results"] if isinstance(pers_res.data, dict) else pers_res.data
        pers_ids = [t["id"] for t in pers_items]
        self.assertIn(personal_id, pers_ids)
        self.assertNotIn(self.admin_task.id, pers_ids)

    def test_no_self_notification_on_personal_card_create_or_complete(self):
        Notification.objects.all().delete()
        self.client.force_authenticate(user=self.emp1_user)
        res = self.client.post(
            "/api/task-management/tasks/",
            {"title": "Quiet Personal Card"},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Notification.objects.filter(user=self.emp1_user).count(), 0)

        # Moving own card to done should not self-notify either
        self.client.patch(
            f"/api/task-management/tasks/{res.data['id']}/move/",
            {"status": "done"},
            format="json",
        )
        self.assertEqual(Notification.objects.filter(user=self.emp1_user).count(), 0)

        # Admin assigning a task to emp1 STILL sends a notification (zero regression)
        self.client.force_authenticate(user=self.admin_user)
        admin_res = self.client.post(
            "/api/task-management/tasks/",
            {
                "title": "Admin Delegated Task",
                "project": self.assigned_project.id,
                "assigned_to": self.emp1.id,
            },
            format="json",
        )
        self.assertEqual(admin_res.status_code, status.HTTP_201_CREATED)
        self.assertGreaterEqual(Notification.objects.filter(user=self.emp1_user).count(), 1)

    def test_standalone_non_employee_blocked_from_creating_task(self):
        self.client.force_authenticate(user=self.finance_user)
        res = self.client.post(
            "/api/task-management/tasks/",
            {"title": "Finance shouldn't create"},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_task_summary_utils_include_personal_tasks_safely(self):
        Task.objects.create(
            project=None,
            created_by=self.emp1,
            assigned_to=self.emp1,
            title="Org Personal Task",
            status="in-progress",
            is_personal=True,
            created_at=self.today,
            updated_at=self.today,
            planned_start_date=self.today,
            planned_end_date=self.today,
        )
        emp_summary = get_employee_task_summary(self.emp1, self.today.year, self.today.month)
        self.assertEqual(emp_summary["on_going_tasks"], 1)
        self.assertEqual(emp_summary["pending_tasks"], 1)

        org_summary = get_organization_task_summary(self.org, self.today.year, self.today.month)
        self.assertEqual(org_summary["on_going_tasks"], 1)
        self.assertEqual(org_summary["pending_tasks"], 1)
