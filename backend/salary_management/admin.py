from django.contrib import admin
from django.http import HttpRequest
from .models import SalaryTransaction, Salary, SalaryTransactionReview, FinanceAccess


class SalaryTransactionReviewAdmin(admin.ModelAdmin):
    list_display = ('Employee', 'Organization', 'transaction', 'created_at')


class SalaryTransactionAdmin(admin.ModelAdmin):
    list_display = ('salary', 'organization', 'date', 'status')
    search_fields = ('organization', )
    list_filter = ('organization', 'date')


class SalaryAdmin(admin.ModelAdmin):
    list_display = ('employee', 'organization', 'basic_salary')
    search_fields = ('employee__first_name',
                     'employee__last_name', 'organization__name')
    list_filter = ('organization',)


# Register your models here.
admin.site.register(Salary, SalaryAdmin)
admin.site.register(SalaryTransaction, SalaryTransactionAdmin)
admin.site.register(SalaryTransactionReview)


@admin.register(FinanceAccess)
class FinanceAccessAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'organization', 'is_active', 'created_at')
    list_filter = ('organization', 'is_active')
    search_fields = ('user__email', 'user__first_name', 'user__last_name')
