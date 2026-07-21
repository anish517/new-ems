from django.contrib import admin
from .models import Complain, ComplainReply, ComplainCategory
# Register your models here.


class ComplainCategoryAdmin(admin.ModelAdmin):
    list_display = ('title', 'organization', 'created_at', 'updated_at')
    search_fields = ('title', 'organization__name')
    list_filter = ('created_at',)
    fields = ('organization', 'title', 'created_at', 'updated_at')
    readonly_fields = ('created_at', 'updated_at')


class ReplyAdmin(admin.ModelAdmin):
    list_display = ('employee', 'complain', 'created_at', 'updated_at')
    list_filter = ('organization', 'created_at')


class ComplainAdmin(admin.ModelAdmin):
    list_display = ('title', 'owner', 'visibility', 'created_at')
    list_filter = ('visibility', 'created_at')
    search_fields = ('title', 'employee__user__first_name',
                     'employee__user__last_name')
    readonly_fields = ('created_at', 'updated_at')


admin.site.register(ComplainCategory, ComplainCategoryAdmin)
admin.site.register(Complain, ComplainAdmin)
admin.site.register(ComplainReply, ReplyAdmin)
