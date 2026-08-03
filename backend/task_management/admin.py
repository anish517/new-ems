from django.contrib import admin
from .models import Project, ProjectAssignment, ProjectFile, Task, TaskFile, TaskProgressReport


class ProjectAssignmentInline(admin.TabularInline):
    model = ProjectAssignment
    extra = 1


class ProjectFileInline(admin.TabularInline):
    model = ProjectFile
    extra = 0


class ProjectAdmin(admin.ModelAdmin):
    list_display = ("title", "organization", "project_type", "status", "created_by", "created_at")
    search_fields = ("title", "organization__name")
    list_filter = ("project_type", "status", "created_at")
    inlines = (ProjectAssignmentInline, ProjectFileInline)


class TaskProgressReportInline(admin.TabularInline):
    model = TaskProgressReport
    extra = 0
    readonly_fields = ("created_at",)


class TaskFileInline(admin.TabularInline):
    model = TaskFile
    extra = 1


class TaskAdmin(admin.ModelAdmin):
    list_display = ("title", "project", "task_type", "assigned_to", "status", "priority", "created_at")
    search_fields = ("title", "project__title")
    list_filter = ("task_type", "status", "priority", "created_at")
    inlines = (TaskFileInline, TaskProgressReportInline)


class TaskProgressReportAdmin(admin.ModelAdmin):
    list_display = ("task", "submitted_by", "date", "created_at")
    list_filter = ("date",)
    search_fields = ("task__title", "description")


admin.site.register(Project, ProjectAdmin)
admin.site.register(ProjectFile)
admin.site.register(ProjectAssignment)
admin.site.register(Task, TaskAdmin)
admin.site.register(TaskProgressReport, TaskProgressReportAdmin)
