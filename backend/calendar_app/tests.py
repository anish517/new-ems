import nepali_datetime
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from authentication.models import Account
from calendar_app.excel_utils import EXCEL_HEADERS, build_events_xlsx, parse_events_xlsx
from calendar_app.models import Event
from organization.models import Department, Employee, Organization, Post


class CalendarExcelExportImportTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.org = Organization.objects.create(name="Calendar Org")
        self.dept = Department.objects.create(organization=self.org, department_name="HR")
        self.post = Post.objects.create(department=self.dept, title="Developer")

        self.admin_user = Account.objects.create(
            email="cal.admin@omway.com",
            first_name="Cal",
            last_name="Admin",
            is_superuser=True,
        )
        self.org.admin_users.add(self.admin_user)

        self.emp_user = Account.objects.create(
            email="cal.emp@omway.com",
            first_name="Cal",
            last_name="Employee",
        )
        self.emp = Employee.objects.create(user=self.emp_user, post=self.post)

        self.event1 = Event.objects.create(
            organization=self.org,
            title="Udhauli Parba",
            start=nepali_datetime.date(2083, 8, 10),
            end=nepali_datetime.date(2083, 8, 10),
            is_holiday=True,
            is_important=True,
        )
        self.event2 = Event.objects.create(
            organization=self.org,
            title="New Year Celebration",
            start=nepali_datetime.date(2083, 1, 1),
            end=nepali_datetime.date(2083, 1, 1),
            is_holiday=True,
            is_important=False,
        )

    def test_employee_can_view_events_but_cannot_export_template_or_import(self):
        self.client.force_authenticate(user=self.emp_user)

        # Employee CAN view calendar events
        list_res = self.client.get("/api/calendar/events/?year=2083&month=8")
        self.assertEqual(list_res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(list_res.data["events"]), 1)

        # Employee CANNOT export, download template, or import
        exp_res = self.client.get("/api/calendar/events/export/?year=2083&month=8")
        self.assertEqual(exp_res.status_code, status.HTTP_403_FORBIDDEN)

        tpl_res = self.client.get("/api/calendar/events/template/")
        self.assertEqual(tpl_res.status_code, status.HTTP_403_FORBIDDEN)

        xlsx_bytes = build_events_xlsx([
            ["Unauthorized Event", "2083-08-15", "2083-08-15", "No", "No"],
        ])
        upload = SimpleUploadedFile(
            "events.xlsx",
            xlsx_bytes,
            content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
        imp_res = self.client.post("/api/calendar/events/import/", {"file": upload}, format="multipart")
        self.assertEqual(imp_res.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_can_download_template_with_headers_and_samples(self):
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.get("/api/calendar/events/template/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(
            res["Content-Type"],
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
        self.assertIn("calendar_events_template.xlsx", res["Content-Disposition"])

        rows = parse_events_xlsx(res.content)
        self.assertGreaterEqual(len(rows), 3)
        self.assertEqual(rows[0], EXCEL_HEADERS)
        self.assertEqual(rows[1][0], "Dashain Festival Holiday")

    def test_admin_can_export_month_year_and_all_scopes(self):
        self.client.force_authenticate(user=self.admin_user)

        # Month scope (2083-08 -> 1 event)
        m_res = self.client.get("/api/calendar/events/export/?year=2083&month=8&scope=month")
        self.assertEqual(m_res.status_code, status.HTTP_200_OK)
        m_rows = parse_events_xlsx(m_res.content)
        self.assertEqual(len(m_rows), 2)  # header + 1 event
        self.assertEqual(m_rows[1][0], "Udhauli Parba")
        self.assertEqual(m_rows[1][1], "2083-08-10")
        self.assertEqual(m_rows[1][3], "Yes")

        # Year scope (2083 -> 2 events)
        y_res = self.client.get("/api/calendar/events/export/?year=2083&scope=year")
        self.assertEqual(y_res.status_code, status.HTTP_200_OK)
        y_rows = parse_events_xlsx(y_res.content)
        self.assertEqual(len(y_rows), 3)  # header + 2 events

    def test_admin_bulk_import_creates_events_skips_duplicates_and_reports_row_errors(self):
        self.client.force_authenticate(user=self.admin_user)

        rows = [
            # Valid new holiday
            ["Constitution Day", "2083-06-03", "2083-06-03", "Yes", "Yes"],
            # Valid event with blank End Date (defaults to Start Date)
            ["Sprint Planning", "2083-08-18", "", "No", "Yes"],
            # Duplicate of existing event1 ("Udhauli Parba", 2083-08-10 -> 2083-08-10)
            ["Udhauli Parba", "2083-08-10", "2083-08-10", "Yes", "True"],
            # Invalid B.S. date (Mangsir 2083 only has 29 days -> 2083-08-30 is invalid)
            ["Bad Date Event", "2083-08-30", "2083-08-30", "No", "No"],
            # End date earlier than Start date
            ["Backwards Event", "2083-08-20", "2083-08-15", "No", "No"],
        ]
        xlsx_bytes = build_events_xlsx(rows)
        upload = SimpleUploadedFile(
            "bulk_events.xlsx",
            xlsx_bytes,
            content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )

        res = self.client.post("/api/calendar/events/import/", {"file": upload}, format="multipart")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["created"], 2)
        self.assertEqual(res.data["skipped"], 1)
        self.assertEqual(len(res.data["errors"]), 2)

        # Verify created events
        self.assertTrue(Event.objects.filter(organization=self.org, title="Constitution Day", is_holiday=True).exists())
        self.assertTrue(Event.objects.filter(organization=self.org, title="Sprint Planning", is_important=True).exists())

        # Re-importing the exact same file skips the 2 newly created events too
        upload2 = SimpleUploadedFile(
            "bulk_events.xlsx",
            xlsx_bytes,
            content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
        res2 = self.client.post("/api/calendar/events/import/", {"file": upload2}, format="multipart")
        self.assertEqual(res2.status_code, status.HTTP_200_OK)
        self.assertEqual(res2.data["created"], 0)
        self.assertEqual(res2.data["skipped"], 3)
