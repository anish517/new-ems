from django.contrib import admin
from .models import Contract

# Register your models here.


@admin.register(Contract)
class ContractAdmin(admin.ModelAdmin):
    model = Contract
    fields = ['organization', 'employee', 'start_date', 'end_date',
              'responsibilites', 'created_at', 'updated_at']
    search_fields = ['employee__user__first_name', 'employee__user__last_name']
    list_display = ['employee', 'organization', 'start_date',
                    'end_date', 'created_at', 'updated_at']
    list_filter = ['created_at', 'updated_at']
    readonly_fields = ['created_at', 'updated_at']
