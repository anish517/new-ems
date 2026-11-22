from django.contrib import admin
from performance.models import PerformanceCategory, PerformanceReview, PerformanceReviewerAccess


@admin.register(PerformanceCategory)
class PerformanceCategoryAdmin(admin.ModelAdmin):
    list_display = ('id', 'name', 'organization', 'created_at')
    list_filter = ('organization',)
    search_fields = ('name',)


@admin.register(PerformanceReview)
class PerformanceReviewAdmin(admin.ModelAdmin):
    list_display = ('id', 'employee', 'reviewer', 'category', 'score', 'created_at')
    list_filter = ('category', 'score', 'created_at')
    search_fields = ('employee__user__first_name', 'employee__user__last_name', 'reviewer__email')


@admin.register(PerformanceReviewerAccess)
class PerformanceReviewerAccessAdmin(admin.ModelAdmin):
    list_display = ('id', 'reviewer', 'organization', 'linked_employee', 'is_active', 'created_at')
    list_filter = ('organization', 'is_active')
    filter_horizontal = ('categories',)
    search_fields = ('reviewer__email', 'reviewer__first_name', 'reviewer__last_name')
