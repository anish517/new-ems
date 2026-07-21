from django.contrib import admin
from django.http import HttpRequest
from .models import SalaryTransaction, Salary, SalaryTransactionReview


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
