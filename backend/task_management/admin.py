from django.contrib import admin
from .models import Project, ProjectFile, Task, TaskFile
# Register your models here.


class ProjectFileInline(admin.TabularInline):
    model = ProjectFile
    extra = 0


class ProjectAdmin(admin.ModelAdmin):
    list_display = ('title', 'organization', 'created_by',
                    'created_at', 'updated_at')
    search_fields = ('title', 'organization__name',)
    list_filter = ('created_at', 'updated_at',)
    inlines = (ProjectFileInline, )


class TaskFileInline(admin.TabularInline):
    model = TaskFile
    extra = 1


class TaskAdmin(admin.ModelAdmin):
    list_display = ('title', 'project', 'created_by',
                    'created_at', 'updated_at', 'status')
    search_fields = ('title', 'project__title')
    list_filter = ('created_at', 'status',)
    inlines = (TaskFileInline, )


admin.site.register(Project, ProjectAdmin)
admin.site.register(ProjectFile)
admin.site.register(Task, TaskAdmin)
