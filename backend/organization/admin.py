from typing import Any
from django.contrib import admin
from django.http import HttpRequest
from .models import (BankDetail, Document, EmployeeAnalysisReport, EmployeeAnalysisReportFeedback, NationalIdDetail, Organization, OrganizationType,
                     OrganizationAddress, Department, Post, Employee, EmployeeDocument, OtherDocument, OrganizationFile, OrganizationFolder, Address, Qualification)

# Register your models here.


class OrganizationAddressInline(admin.StackedInline):
    model = OrganizationAddress
    extra = 0  # Number of empty forms to display


class DepartmentInline(admin.TabularInline):
    model = Department
    extra = 0

    def has_add_permission(self, request: HttpRequest, obj) -> bool:
        return False

    def has_delete_permission(self, request: HttpRequest, obj) -> bool:
        return False

    def has_change_permission(self, request: HttpRequest, obj) -> bool:
        return False


class PostInline(admin.TabularInline):
    model = Post
    extra = 0


class EmployeeInline(admin.TabularInline):
    model = Employee
    extra = 0
    fields = ('user', 'post', 'gender', 'date_of_birth',
              'father_name', 'phone_no', 'official_email', 'personal_email')
    readonly_fields = ('user', 'post', 'gender',
                       'date_of_birth', 'father_name', 'phone_no', 'official_email', 'personal_email')

    def has_delete_permission(self, request: HttpRequest, obj) -> bool:
        return False

    def has_add_permission(self, request: HttpRequest, obj) -> bool:
        return False


class EmployeeAddressInline(admin.TabularInline):
    model = Address
    extra = 0
    fields = ('state', 'district', 'street', 'type')


class NationalIdDetailInline(admin.TabularInline):
    model = NationalIdDetail
    extra = 0
    fields = ('national_id_no', 'citizenship_no', 'martial_status')


class EmployeeQualificationInline(admin.TabularInline):
    model = Qualification
    extra = 0
    fields = ('college', 'degree', 'field_of_study', 'start_date', 'end_date')


class EmployeeBankDetailsInline(admin.TabularInline):
    model = BankDetail
    extra = 0
    fields = ('bank_name', 'account_number')


class EmployeeDocumentInline(admin.TabularInline):
    model = Document
    extra = 0
    fields = ('name', 'file')


class OrganizationAdmin(admin.ModelAdmin):
    list_display = ('name', 'type_of_organization',)
    inlines = [OrganizationAddressInline, DepartmentInline]


class DepartmentAdmin(admin.ModelAdmin):
    list_display = ('organization', 'department_name',
                    'department_slug', 'parent_department')
    search_fields = ('organization', 'department_name')
    inlines = [PostInline]
    list_per_page = 20
    fieldsets = (
        ('Basic Information', {  # Title of the first fieldset
            # Fields to include in this section
            'fields': ('organization', 'department_name', 'parent_department', 'department_slug')
        },),
    )
    readonly_fields = ['department_slug']


class PostAdmin(admin.ModelAdmin):
    list_display = ('title', 'organization', 'department', )
    inlines = [EmployeeInline]

    def organization(self, obj):
        return obj.department.organization


class EmployeeAdmin(admin.ModelAdmin):
    list_display = ('user', 'post',
                    'gender', 'phone_no', 'employee_type')
    inlines = (EmployeeAddressInline, NationalIdDetailInline, EmployeeQualificationInline, EmployeeBankDetailsInline,
               EmployeeDocumentInline, )
    fieldsets = (
        ('Basic Information', {
            'fields': ('user', 'gender', 'date_of_birth')
        }),
        ('Contact details', {
            'fields': ('phone_no', 'official_email', 'personal_email'),
        }),
        ('Official details', {
            'fields': ('post',),
        }),
        ('Status', {
            'fields': ('is_active',)
        })
    )


class EmployeeAnalysisReportAdmin(admin.ModelAdmin):
    list_display = ('organization', 'employee', 'date',
                    'task_score', 'attendance_score')


admin.site.register(Organization, OrganizationAdmin)
admin.site.register(OrganizationType)
admin.site.register(Department, DepartmentAdmin)
admin.site.register(Post, PostAdmin)
admin.site.register(Employee, EmployeeAdmin)
admin.site.register(EmployeeAnalysisReport, EmployeeAnalysisReportAdmin)
admin.site.register(EmployeeAnalysisReportFeedback)
admin.site.register(OrganizationFolder)
admin.site.register(OrganizationFile)
