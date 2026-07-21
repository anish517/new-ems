from django.contrib import admin

from attendance.models import Attendance, CheckInOut, RemoteWorkPermission

# Register your models here.


class CheckInOutInline(admin.TabularInline):
    model = CheckInOut
    extra = 1  # Number of blank forms to display


class AttendanceAdmin(admin.ModelAdmin):
    list_display = ('employee', 'organization', 'date', 'has_checked_in')
    search_fields = ('employee__user__first_name',
                     'employee__user__last_name', 'organization__name')
    readonly_fields = ('check_in_lat', 'check_in_lng',
                       'check_out_lat', 'check_out_lng')
    inlines = [CheckInOutInline]


class CheckInOutAdmin(admin.ModelAdmin):
    list_display = ('attendance', 'check_in', 'check_out')


admin.site.register(Attendance, AttendanceAdmin)
admin.site.register(CheckInOut, CheckInOutAdmin)


@admin.register(RemoteWorkPermission)
class RemoteWorkPermissionAdmin(admin.ModelAdmin):
    list_display = ('employee', 'is_allowed', 'remote_lat', 'remote_lng')
