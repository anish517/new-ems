from django.contrib import admin
from .models import Notice, NoticeFile, CompanyPolicy, PolicyApproval
# Register your models here.

admin.site.register(Notice)
admin.site.register(NoticeFile)
admin.site.register(CompanyPolicy)

@admin.register(PolicyApproval)
class PolicyApprovalAdmin(admin.ModelAdmin):
    list_display = ('user', 'employee', 'approved_at', 'device_name', 'os', 'browser', 'ip_address')
    list_filter = ('is_approved', 'approved_at', 'os', 'browser')
    search_fields = ('user__email', 'user__first_name', 'user__last_name', 'device_name', 'ip_address')