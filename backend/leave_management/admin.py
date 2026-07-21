from django.contrib import admin
from .models import LeaveBalance, LeaveRequest, LeaveType

# Register your models here.


class LeaveRequestAdmin(admin.ModelAdmin):
    list_display = ('subject', 'employee', 'type', 'no_days',
                    'is_reviewed', 'is_approved', 'is_paid', 'created_at')
    search_fields = ('employee__user__first_name',
                     'employee__user__last_name', 'type__name', 'subject')
    list_filter = ('type', 'is_approved', 'is_reviewed',
                   'is_paid', 'created_at')

    fieldsets = (
        ('Leave Request Details', {
            'fields': ('organization', 'employee', 'type', 'from_date', 'till_date', 'subject', 'reason_for_leave')
        }),
        ('Approval and Payment', {
            'fields': ('is_approved', 'is_reviewed', 'is_paid', 'remarks'),
        }),
        ('Audit Information', {
            'fields': ('created_at',),
        }),
    )


class LeaveTypeAdmin(admin.ModelAdmin):
    list_display = ('name', 'organization', 'quota')
    search_fields = ('name', 'organization__name')
    list_filter = ('organization',)


class LeaveBalanceAdmin(admin.ModelAdmin):
    list_display = ('employee', 'organization',
                    'leave_type', 'quota', 'leaves_taken')
    search_fields = ('employee__user__first_name',
                     'employee__user__last_name', 'leave_type__name', 'organization__name')
    list_filter = ('organization', 'leave_type')


admin.site.register(LeaveRequest, LeaveRequestAdmin)
admin.site.register(LeaveType, LeaveTypeAdmin)
admin.site.register(LeaveBalance, LeaveBalanceAdmin)
