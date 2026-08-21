from django.utils import timezone
from rest_framework import status, generics, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser

from notification.models import Notification
from notification.fcm import notify_user
from organization.models import Employee, Organization
from task_management.models import Project, ProjectAssignment, ProjectFile, Task, TaskProgressReport
from task_management.utils import (
    get_employee_task_summary, get_organization_project_summary,
    get_organization_task_summary, get_project_task_summary,
)
from .serializers import ProjectSerializer, TaskProgressReportSerializer, TaskSerializer


# ─── Helpers ────────────────────────────────────────────────────────────────

def _get_employee(user):
    try:
        return user.employee
    except Exception:
        return None


def _get_org(user, employee=None):
    if employee and getattr(employee, "organization", None):
        return employee.organization
    orgs = user.organization.all()
    if orgs.exists():
        return orgs.first()
    if getattr(user, "is_superuser", False) or getattr(user, "is_hr", False):
        return Organization.objects.first()
    return None


def _is_admin_user(user, employee=None):
    if not user or not user.is_authenticated:
        return False
    if getattr(user, "is_superuser", False) or getattr(user, "is_admin", False) or getattr(user, "is_hr", False):
        return True
    if hasattr(user, "organization") and user.organization.exists():
        return True
    if employee and getattr(employee, "post", None):
        post_title = (employee.post.title or "").lower()
        if any(w in post_title for w in ["admin", "manager", "director", "lead", "head", "ceo", "cto", "coo", "hr"]):
            return True
    return False



# ─── Project CRUD ────────────────────────────────────────────────────────────

class ProjectListCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get(self, request):
        employee = _get_employee(request.user)
        org = _get_org(request.user, employee)
        if not org:
            return Response([])

        qs = Project.objects.filter(organization=org)
        
        is_admin = request.user.organization.exists() or getattr(request.user, "is_superuser", False) or getattr(request.user, "is_hr", False)
        if not is_admin and employee:
            from django.db.models import Q
            qs = qs.filter(Q(assignments__employee=employee) | Q(created_by=employee)).distinct()

        # Filter by status tab
        status_filter = request.GET.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter)

        serializer = ProjectSerializer(qs.order_by("-id"), many=True, context={"request": request})
        return Response(serializer.data)

    def post(self, request):
        employee = _get_employee(request.user)
        org = _get_org(request.user, employee)
        if not org:
            return Response({"error": "No organization found"}, status=400)

        serializer = ProjectSerializer(data=request.data, context={"request": request})
        if serializer.is_valid():
            serializer.save(organization=org, created_by=employee)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ProjectRetrieveUpdateDestroyAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def _get_project(self, pk, request):
        employee = _get_employee(request.user)
        org = _get_org(request.user, employee)
        try:
            return Project.objects.get(pk=pk, organization=org)
        except Project.DoesNotExist:
            return None

    def get(self, request, pk):
        project = self._get_project(pk, request)
        if not project:
            return Response({"error": "Not found"}, status=404)
        return Response(ProjectSerializer(project, context={"request": request}).data)

    def patch(self, request, pk):
        project = self._get_project(pk, request)
        if not project:
            return Response({"error": "Not found"}, status=404)
        serializer = ProjectSerializer(project, data=request.data, partial=True, context={"request": request})
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=400)

    def delete(self, request, pk):
        project = self._get_project(pk, request)
        if not project:
            return Response({"error": "Not found"}, status=404)
        project.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ProjectFileUploadAPIView(APIView):
    """Upload one or more files to a project."""
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, pk):
        try:
            project = Project.objects.get(pk=pk)
        except Project.DoesNotExist:
            return Response({"error": "Not found"}, status=404)

        files = request.FILES.getlist("files")
        for f in files:
            ProjectFile.objects.create(project=project, title=f.name, file=f)
        return Response({"status": "uploaded", "count": len(files)}, status=201)

    def delete(self, request, pk):
        file_id = request.data.get("file_id")
        try:
            pf = ProjectFile.objects.get(pk=file_id, project_id=pk)
            pf.delete()
        except ProjectFile.DoesNotExist:
            return Response({"error": "Not found"}, status=404)
        return Response(status=204)


# ─── Task CRUD ───────────────────────────────────────────────────────────────

class TaskListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = TaskSerializer
    permission_classes = [permissions.IsAuthenticated]
    nepali_date_filter_field = "planned_start_date"

    def get_queryset(self):
        user = self.request.user
        employee = _get_employee(user)
        org = _get_org(user, employee)
        if not org:
            return Task.objects.none()

        projects = Project.objects.filter(organization=org)
        all_tasks = Task.objects.filter(project__in=projects)
        is_admin = user.organization.exists() or user.is_superuser or getattr(user, "is_hr", False)

        # Optional filters
        assigned_to_id = self.request.GET.get("assigned_to")
        project_id = self.request.GET.get("project")
        start_date_str = self.request.GET.get("start_date")
        end_date_str = self.request.GET.get("end_date")

        if project_id:
            all_tasks = all_tasks.filter(project_id=project_id)

        if start_date_str and end_date_str:
            try:
                import nepali_datetime
                from django.db.models import Q
                sy, sm, sd = map(int, start_date_str.split("-"))
                ey, em, ed = map(int, end_date_str.split("-"))
                start_date = nepali_datetime.date(sy, sm, sd)
                end_date = nepali_datetime.date(ey, em, ed)
                all_tasks = all_tasks.filter(
                    Q(planned_start_date__lte=end_date) &
                    (Q(planned_end_date__gte=start_date) | Q(planned_end_date__isnull=True))
                )
            except Exception:
                pass

        if is_admin:
            if assigned_to_id:
                return all_tasks.filter(assigned_to_id=assigned_to_id).order_by("-id")
            return all_tasks.order_by("-id")

        if employee:
            return all_tasks.filter(assigned_to=employee).order_by("-id")
        return Task.objects.none()

    def perform_create(self, serializer):
        import nepali_datetime
        today = nepali_datetime.date.today()
        employee = _get_employee(self.request.user)
        serializer.save(created_by=employee, created_at=today, updated_at=today)


class TaskRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = TaskSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_queryset(self):
        employee = _get_employee(self.request.user)
        org = _get_org(self.request.user, employee)
        if not org:
            return Task.objects.none()
        projects = Project.objects.filter(organization=org)
        return Task.objects.filter(project__in=projects)


# ─── Task Progress Reports ────────────────────────────────────────────────────

class TaskProgressReportListCreateAPIView(APIView):
    """List all progress reports for a task, or submit a new one."""
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get(self, request, task_id):
        try:
            task = Task.objects.get(pk=task_id)
        except Task.DoesNotExist:
            return Response({"error": "Task not found"}, status=404)
        reports = task.progress_reports.all()
        serializer = TaskProgressReportSerializer(reports, many=True, context={"request": request})
        return Response(serializer.data)

    def post(self, request, task_id):
        try:
            task = Task.objects.get(pk=task_id)
        except Task.DoesNotExist:
            return Response({"error": "Task not found"}, status=404)

        employee = _get_employee(request.user)
        data = request.data.copy()
        data["task"] = task_id
        if not data.get("date"):
            import datetime
            data["date"] = str(datetime.date.today())

        serializer = TaskProgressReportSerializer(data=data, context={"request": request})
        if serializer.is_valid():
            serializer.save(submitted_by=employee)
            return Response(serializer.data, status=201)
        return Response(serializer.errors, status=400)


class TaskProgressReportDestroyAPIView(APIView):
    """Delete a single progress report. Super Admin / Admin can delete directly; regular employees must request deletion."""
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, pk):
        try:
            report = TaskProgressReport.objects.select_related("task", "submitted_by__user").get(pk=pk)
        except TaskProgressReport.DoesNotExist:
            return Response({"error": "Not found"}, status=404)

        employee = _get_employee(request.user)
        is_admin = _is_admin_user(request.user, employee)

        if not is_admin:
            return Response(
                {"error": "Employees cannot delete progress reports directly. Please submit a deletion request with a reason for Super Admin approval."},
                status=status.HTTP_403_FORBIDDEN
            )

        report.delete()
        return Response(status=204)


class TaskProgressReportRequestDeletionAPIView(APIView):
    """Employee submits a deletion request for a progress report with a mandatory reason."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            report = TaskProgressReport.objects.select_related("task", "submitted_by__user").get(pk=pk)
        except TaskProgressReport.DoesNotExist:
            return Response({"error": "Progress report not found"}, status=404)

        reason = str(request.data.get("reason", "")).strip()
        if not reason:
            return Response({"error": "A reason for deletion is required."}, status=status.HTTP_400_BAD_REQUEST)

        employee = _get_employee(request.user)
        report.is_deletion_requested = True
        report.deletion_reason = reason
        report.deletion_requested_by = employee
        report.deletion_requested_at = timezone.now()
        report.save(update_fields=["is_deletion_requested", "deletion_reason", "deletion_requested_by", "deletion_requested_at"])

        # Notify Super Admins / Org Admins
        emp_name = "Employee"
        if employee and employee.user:
            emp_name = getattr(employee.user, "full_name", "") or getattr(employee.user, "username", "Employee")

        task_title = report.task.title if report.task else "Task"
        notif_title = "🗑️ Progress Report Deletion Request"
        notif_msg = f"{emp_name} requested to delete a progress log on \"{task_title}\". Reason: {reason}"

        # Send FCM & In-App notification to Org Admins / Super Admins
        try:
            org = _get_org(request.user, employee)
            admin_users = []
            if org:
                admin_users = list(org.admin_users.all())
            else:
                from authentication.models import Account
                admin_users = list(Account.objects.filter(is_superuser=True))

            for admin_user in admin_users:
                Notification.objects.create(
                    user=admin_user,
                    title=notif_title,
                    message=notif_msg,
                    notification_type="task",
                    reference_id=report.id,
                    is_read=False,
                )
                notify_user(
                    user=admin_user,
                    title=notif_title,
                    body=notif_msg,
                    notification_type="task",
                    reference_id=report.id,
                )
        except Exception as e:
            print(f"[TaskProgressReport] Notification error: {e}")

        serializer = TaskProgressReportSerializer(report, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)


class TaskProgressReportApproveDeletionAPIView(APIView):
    """Super Admin approves a deletion request, permanently deleting the progress report."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            report = TaskProgressReport.objects.select_related("task", "submitted_by__user", "deletion_requested_by__user").get(pk=pk)
        except TaskProgressReport.DoesNotExist:
            return Response({"error": "Progress report not found"}, status=404)

        employee = _get_employee(request.user)
        if not _is_admin_user(request.user, employee):
            return Response({"error": "Only Super Admins / Admins can approve deletion requests."}, status=status.HTTP_403_FORBIDDEN)

        target_user = None
        if report.deletion_requested_by and report.deletion_requested_by.user:
            target_user = report.deletion_requested_by.user
        elif report.submitted_by and report.submitted_by.user:
            target_user = report.submitted_by.user

        task_title = report.task.title if report.task else "Task"

        if target_user:
            notif_title = "✅ Deletion Request Approved"
            notif_msg = f"Your deletion request for progress log on \"{task_title}\" was approved and deleted."
            try:
                Notification.objects.create(
                    user=target_user,
                    title=notif_title,
                    message=notif_msg,
                    notification_type="task",
                    reference_id=report.task_id,
                    is_read=False,
                )
                notify_user(
                    user=target_user,
                    title=notif_title,
                    body=notif_msg,
                    notification_type="task",
                    reference_id=report.task_id,
                )
            except Exception as e:
                print(f"[TaskProgressReport] Notification error: {e}")

        report.delete()
        return Response({"detail": "Progress report deleted successfully."}, status=status.HTTP_200_OK)


class TaskProgressReportRejectDeletionAPIView(APIView):
    """Super Admin rejects a deletion request, restoring the progress report."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            report = TaskProgressReport.objects.select_related("task", "submitted_by__user", "deletion_requested_by__user").get(pk=pk)
        except TaskProgressReport.DoesNotExist:
            return Response({"error": "Progress report not found"}, status=404)

        employee = _get_employee(request.user)
        if not _is_admin_user(request.user, employee):
            return Response({"error": "Only Super Admins / Admins can reject deletion requests."}, status=status.HTTP_403_FORBIDDEN)

        rejection_reason = str(request.data.get("rejection_reason", "")).strip()
        target_user = None
        if report.deletion_requested_by and report.deletion_requested_by.user:
            target_user = report.deletion_requested_by.user
        elif report.submitted_by and report.submitted_by.user:
            target_user = report.submitted_by.user

        task_title = report.task.title if report.task else "Task"

        report.is_deletion_requested = False
        report.deletion_reason = None
        report.deletion_requested_by = None
        report.deletion_requested_at = None
        report.save(update_fields=["is_deletion_requested", "deletion_reason", "deletion_requested_by", "deletion_requested_at"])

        if target_user:
            reason_suffix = f" Reason: {rejection_reason}" if rejection_reason else ""
            notif_title = "❌ Deletion Request Declined"
            notif_msg = f"Your deletion request for progress log on \"{task_title}\" was declined.{reason_suffix}"
            try:
                Notification.objects.create(
                    user=target_user,
                    title=notif_title,
                    message=notif_msg,
                    notification_type="task",
                    reference_id=report.id,
                    is_read=False,
                )
                notify_user(
                    user=target_user,
                    title=notif_title,
                    body=notif_msg,
                    notification_type="task",
                    reference_id=report.id,
                )
            except Exception as e:
                print(f"[TaskProgressReport] Notification error: {e}")

        serializer = TaskProgressReportSerializer(report, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)



# ─── Summary Views ───────────────────────────────────────────────────────────

class EmployeeTaskSummaryAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, employee_id):
        try:
            employee = Employee.objects.get(id=employee_id)
        except Employee.DoesNotExist:
            return Response({"error": "Employee not found"}, status=404)
        ny = request.GET.get("nepali_year")
        nm = request.GET.get("nepali_month")
        if ny and nm:
            data = get_employee_task_summary(employee=employee, year=int(ny), month=int(nm))
        else:
            data = get_employee_task_summary(employee=employee)
        return Response(data)


class OrganizationTaskSummaryAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, organization_id):
        try:
            organization = Organization.objects.get(id=organization_id)
        except Organization.DoesNotExist:
            return Response({"error": "Organization not found"}, status=404)
        ny = request.GET.get("nepali_year")
        nm = request.GET.get("nepali_month")
        if ny and nm:
            data = get_organization_task_summary(organization=organization, year=int(ny), month=int(nm))
        else:
            data = get_organization_task_summary(organization=organization)
        return Response(data)


class ProjectTaskSummaryAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, project_id):
        try:
            project = Project.objects.get(id=project_id)
        except Project.DoesNotExist:
            return Response({"error": "Project not found"}, status=404)
        ny = request.GET.get("nepali_year")
        nm = request.GET.get("nepali_month")
        if ny and nm:
            data = get_project_task_summary(project=project, year=int(ny), month=int(nm))
        else:
            data = get_project_task_summary(project=project)
        return Response(data)


class OrganizationProjectSummary(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, organization_id):
        try:
            organization = Organization.objects.get(id=organization_id)
        except Organization.DoesNotExist:
            return Response({"error": "Organization not found"}, status=404)
        data = get_organization_project_summary(organization=organization)
        return Response(data)


class ProjectListAPIView(APIView):
    """Simple flat list of projects for dropdown pickers."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        employee = _get_employee(request.user)
        org = _get_org(request.user, employee)
        if not org:
            return Response([])
        projects = Project.objects.filter(organization=org)
        data = [{"id": p.id, "title": p.title, "project_type": p.project_type, "status": p.status} for p in projects]
        return Response(data)
