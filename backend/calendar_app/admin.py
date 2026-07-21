from django.contrib import admin
from .models import Category, Event

# Register your models here.


class EventInline(admin.TabularInline):
    model = Event
    extra = 1


class CategoryAdmin(admin.ModelAdmin):
    list_display = ('name', )


class EventAdmin(admin.ModelAdmin):
    list_display = ('title', 'start', 'end',
                    'location', 'organization')


admin.site.register(Category, CategoryAdmin)
admin.site.register(Event, EventAdmin)
