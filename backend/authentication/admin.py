from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import Account, LoginHistory

# Register your models here.


class AccountAdmin(UserAdmin):
    model = Account
    list_display = ('email', 'first_name', 'last_name',
                    'date_joined', 'is_active')
    list_filter = ('date_joined',)
    filter_horizontal = ()

    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('BASIC INFORMATION', {
            'fields': ('first_name', 'last_name', 'profile_picture'),
        }),
        ('PERMISSIONS', {'fields': ('is_active', 'is_staff', 'is_superuser')}),
        ('IMPORTANT DATES', {
            'fields': ('last_login', 'date_joined',),
        })
    )
    readonly_fields = ('last_login', 'date_joined',)
    add_fieldsets = (
        ('Personal Information', {
            'classes': ('extrapreety', ),
            'fields': ('email', 'first_name', 'last_name', 'phone_no', 'gender'),
        }),
        ('Permissions', {
            'classes': ('inline', ),
            'fields': ('is_staff', 'is_active', 'is_superuser'),
        }),
        ('Password', {
            'classes': ('wide', ),
            'fields': ('password1', 'password2'),
        })
    )

    search_fields = ('email', 'first_name', 'last_name')
    ordering = ('date_joined', )


class LoginHistoryAdmin(admin.ModelAdmin):
    list_display = ('user', 'browser', 'os', 'timestamp')


admin.site.register(Account, AccountAdmin)
admin.site.register(LoginHistory, LoginHistoryAdmin)
