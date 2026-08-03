import datetime
from rest_framework import serializers

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

    class Meta:
        model = TaskProgressReport
        fields = [
            "id", "task", "date", "description", "attachment",
            "attachment_url", "submitted_by_name", "created_at",
            "hours_worked", "days_worked", "earned_amount"
        ]
        read_only_fields = ["submitted_by_name", "attachment_url", "created_at", "earned_amount"]

    def get_submitted_by_name(self, obj):
        if obj.submitted_by and obj.submitted_by.user:
            user = obj.submitted_by.user
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
        if not obj.task_id or not obj.submitted_by_id:
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
    planned_start_date = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    planned_end_date = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    progress_reports = TaskProgressReportSerializer(many=True, read_only=True)

    class Meta:
        model = Task
        fields = [
            "id", "project", "assigned_to", "title", "task_type",
            "description", "description_pdf", "status", "priority",
            "planned_start_date", "planned_end_date", "rating",
            "progress_reports",
        ]

    def create(self, validated_data):
        import nepali_datetime
        today = nepali_datetime.date.today()
        if not validated_data.get("planned_start_date"):
            validated_data["planned_start_date"] = today
        if not validated_data.get("planned_end_date"):
            validated_data["planned_end_date"] = today
        return super().create(validated_data)

    def to_representation(self, instance):
        rep = super().to_representation(instance)
        rep["project"] = {
            "id": instance.project.id if instance.project else None,
            "name": instance.project.title if instance.project else None,
            "project_type": instance.project.project_type if instance.project else None,
        }
        # Safe extraction for assigned_to
        assigned_name = None
        if instance.assigned_to and instance.assigned_to.user:
            user = instance.assigned_to.user
            if hasattr(user, 'first_name'):
                assigned_name = f"{getattr(user, 'first_name', '')} {getattr(user, 'last_name', '')}".strip()
            else:
                assigned_name = getattr(user, 'full_name', 'Unknown')
                
            if not assigned_name:
                assigned_name = getattr(user, 'username', 'Unknown')

        rep["assigned_to"] = {
            "id": instance.assigned_to.id if instance.assigned_to else None,
            "name": assigned_name,
        }
        return rep
