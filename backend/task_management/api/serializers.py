import datetime
from rest_framework import serializers

from organization.models import Employee
from task_management.models import Project, ProjectAssignment, ProjectFile, Task, TaskProgressReport


class ProjectAssignmentSerializer(serializers.ModelSerializer):
    employee_id = serializers.IntegerField(source="employee.id", read_only=True)
    name = serializers.SerializerMethodField()
    avatar = serializers.SerializerMethodField()
    total_hours = serializers.SerializerMethodField()
    total_days = serializers.SerializerMethodField()
    total_earned = serializers.SerializerMethodField()

    class Meta:
        model = ProjectAssignment
        fields = [
            "id", "employee_id", "role", "hourly_rate", "daily_rate", 
            "name", "avatar", "total_hours", "total_days", "total_earned"
        ]

    def get_name(self, obj):
        if obj.employee and obj.employee.user:
            user = obj.employee.user
            if hasattr(user, 'first_name'):
                name = f"{getattr(user, 'first_name', '')} {getattr(user, 'last_name', '')}".strip()
                if name: return name
            return getattr(user, 'full_name', getattr(user, 'username', 'Unknown'))
        return None

    def get_avatar(self, obj):
        req = self.context.get("request")
        try:
            pic = obj.employee.user.profile.profile_picture
            if pic and req:
                return req.build_absolute_uri(pic.url)
        except Exception:
            pass
        return None

    def _get_aggregated(self, obj):
        if hasattr(obj, '_aggregated'): return obj._aggregated
        reports = TaskProgressReport.objects.filter(
            task__project=obj.project,
            submitted_by=obj.employee
        )
        hours = sum(r.hours_worked for r in reports if r.hours_worked)
        days = sum(r.days_worked for r in reports if r.days_worked)
        earned = 0
        if obj.hourly_rate:
            earned += float(hours) * float(obj.hourly_rate)
        if obj.daily_rate:
            earned += float(days) * float(obj.daily_rate)
        obj._aggregated = {
            "hours": float(hours),
            "days": float(days),
            "earned": earned
        }
        return obj._aggregated

    def get_total_hours(self, obj):
        return self._get_aggregated(obj)["hours"]

    def get_total_days(self, obj):
        return self._get_aggregated(obj)["days"]

    def get_total_earned(self, obj):
        return self._get_aggregated(obj)["earned"]


class ProjectFileSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProjectFile
        fields = ["id", "title", "file"]


class ProjectSerializer(serializers.ModelSerializer):
    assignments = ProjectAssignmentSerializer(many=True, read_only=True)
    files = ProjectFileSerializer(many=True, read_only=True)
    completion = serializers.SerializerMethodField()
    task_counts = serializers.SerializerMethodField()

    # Write-only fields for assigning members
    assign_members = serializers.ListField(
        child=serializers.DictField(), write_only=True, required=False
    )

    class Meta:
        model = Project
        fields = [
            "id", "title", "abbreviation", "description",
            "project_type", "estimated_hours", "total_budget",
            "status", "created_at", "updated_at",
            "assignments", "files", "completion", "task_counts",
            "assign_members",
        ]
        read_only_fields = ["created_at", "updated_at"]

    def get_completion(self, obj):
        return obj.completion()

    def get_task_counts(self, obj):
        tasks = obj.tasks.all()
        return {
            "total": tasks.count(),
            "done": tasks.filter(status="done").count(),
            "in_progress": tasks.filter(status="in-progress").count(),
            "todo": tasks.filter(status="to-do").count(),
        }

    def create(self, validated_data):
        import nepali_datetime
        today = nepali_datetime.date.today()
        assign_members = validated_data.pop("assign_members", [])
        validated_data.setdefault("created_at", today)
        validated_data.setdefault("updated_at", today)
        project = super().create(validated_data)
        self._sync_assignments(project, assign_members)
        return project

    def update(self, instance, validated_data):
        import nepali_datetime
        today = nepali_datetime.date.today()
        assign_members = validated_data.pop("assign_members", None)
        validated_data["updated_at"] = today
        project = super().update(instance, validated_data)
        if assign_members is not None:
            self._sync_assignments(project, assign_members)
        return project

    def _sync_assignments(self, project, assign_members):
        from organization.models import Employee
        ProjectAssignment.objects.filter(project=project).delete()
        for entry in assign_members:
            emp_id = entry.get("employee_id")
            role = entry.get("role", "junior")
            hourly = entry.get("hourly_rate")
            daily = entry.get("daily_rate")
            try:
                emp = Employee.objects.get(id=emp_id)
                ProjectAssignment.objects.create(
                    project=project, employee=emp, role=role,
                    hourly_rate=hourly if hourly else None,
                    daily_rate=daily if daily else None
                )
            except Employee.DoesNotExist:
                pass


class TaskProgressReportSerializer(serializers.ModelSerializer):
    submitted_by_name = serializers.SerializerMethodField()
    attachment_url = serializers.SerializerMethodField()
    earned_amount = serializers.SerializerMethodField()
    deletion_requested_by_name = serializers.SerializerMethodField()

    class Meta:
        model = TaskProgressReport
        fields = [
            "id", "task", "date", "description", "attachment",
            "attachment_url", "submitted_by_name", "created_at",
            "hours_worked", "days_worked", "earned_amount",
            "is_deletion_requested", "deletion_reason",
            "deletion_requested_by_name", "deletion_requested_at",
        ]
        read_only_fields = [
            "submitted_by_name", "attachment_url", "created_at",
            "earned_amount", "deletion_requested_by_name", "deletion_requested_at"
        ]

    def get_submitted_by_name(self, obj):
        if obj.submitted_by and obj.submitted_by.user:
            user = obj.submitted_by.user
            if hasattr(user, 'first_name'):
                name = f"{getattr(user, 'first_name', '')} {getattr(user, 'last_name', '')}".strip()
                if name: return name
            return getattr(user, 'full_name', getattr(user, 'username', 'Unknown'))
        return None

    def get_deletion_requested_by_name(self, obj):
        if obj.deletion_requested_by and obj.deletion_requested_by.user:
            user = obj.deletion_requested_by.user
            if hasattr(user, 'first_name'):
                name = f"{getattr(user, 'first_name', '')} {getattr(user, 'last_name', '')}".strip()
                if name: return name
            return getattr(user, 'full_name', getattr(user, 'username', 'Unknown'))
        return None

    def get_attachment_url(self, obj):
        req = self.context.get("request")
        if obj.attachment and req:
            return req.build_absolute_uri(obj.attachment.url)
        return None

    def get_earned_amount(self, obj):
        if not obj.task_id or not obj.task.project_id or not obj.submitted_by_id:
            return None
        try:
            assignment = ProjectAssignment.objects.get(
                project_id=obj.task.project_id, employee_id=obj.submitted_by_id
            )
            if obj.hours_worked and assignment.hourly_rate:
                return float(obj.hours_worked * assignment.hourly_rate)
            if obj.days_worked and assignment.daily_rate:
                return float(obj.days_worked * assignment.daily_rate)
        except ProjectAssignment.DoesNotExist:
            pass
        return None



class TaskSerializer(serializers.ModelSerializer):
    project = serializers.PrimaryKeyRelatedField(
        queryset=Project.objects.all(), required=False, allow_null=True
    )
    assigned_to = serializers.PrimaryKeyRelatedField(
        queryset=Employee.objects.all(), required=False, allow_null=True
    )
    planned_start_date = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    planned_end_date = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    is_personal = serializers.BooleanField(required=False)
    position = serializers.IntegerField(required=False, min_value=0)
    progress_reports = TaskProgressReportSerializer(many=True, read_only=True)
    progress_count = serializers.SerializerMethodField()
    can_edit = serializers.SerializerMethodField()
    can_delete = serializers.SerializerMethodField()

    class Meta:
        model = Task
        fields = [
            "id", "project", "assigned_to", "created_by", "title", "task_type",
            "description", "description_pdf", "status", "priority",
            "is_personal", "position",
            "planned_start_date", "planned_end_date", "rating",
            "progress_reports", "progress_count", "can_edit", "can_delete",
        ]
        read_only_fields = ["created_by", "progress_count", "can_edit", "can_delete"]

    def _actor_permissions(self, obj):
        request = self.context.get("request")
        user = getattr(request, "user", None)
        if not user or not user.is_authenticated:
            return False
        is_admin = bool(
            getattr(user, "is_superuser", False)
            or getattr(user, "is_admin", False)
            or getattr(user, "is_hr", False)
            or (hasattr(user, "organization") and user.organization.exists())
        )
        if is_admin:
            return True
        try:
            employee = user.employee
        except Exception:
            employee = None
        if employee and obj.created_by_id == employee.id and (obj.is_personal or obj.project_id is None):
            return True
        return False

    def get_progress_count(self, obj):
        return obj.progress_reports.count()

    def get_can_edit(self, obj):
        return self._actor_permissions(obj)

    def get_can_delete(self, obj):
        return self._actor_permissions(obj)

    def _extract_employee_name(self, emp):
        if not emp or not getattr(emp, "user", None):
            return None
        user = emp.user
        name = None
        if hasattr(user, "first_name"):
            name = f"{getattr(user, 'first_name', '')} {getattr(user, 'last_name', '')}".strip()
        if not name:
            name = getattr(user, "full_name", None) or getattr(user, "username", "Unknown")
        return name

    def create(self, validated_data):
        import nepali_datetime
        today = nepali_datetime.date.today()
        if not validated_data.get("planned_start_date"):
            validated_data["planned_start_date"] = today
        if not validated_data.get("planned_end_date"):
            validated_data["planned_end_date"] = today
        return super().create(validated_data)

    def update(self, instance, validated_data):
        if "planned_start_date" in validated_data and not validated_data["planned_start_date"]:
            validated_data.pop("planned_start_date")
        if "planned_end_date" in validated_data and not validated_data["planned_end_date"]:
            validated_data.pop("planned_end_date")
        return super().update(instance, validated_data)

    def to_representation(self, instance):
        rep = super().to_representation(instance)
        rep["project"] = {
            "id": instance.project.id if instance.project else None,
            "name": instance.project.title if instance.project else None,
            "project_type": instance.project.project_type if instance.project else None,
        }
        rep["assigned_to"] = {
            "id": instance.assigned_to.id if instance.assigned_to else None,
            "name": self._extract_employee_name(instance.assigned_to),
        }
        rep["created_by"] = {
            "id": instance.created_by.id if instance.created_by else None,
            "name": self._extract_employee_name(instance.created_by),
        }
        rep["is_personal"] = bool(instance.is_personal or instance.project_id is None)
        return rep
