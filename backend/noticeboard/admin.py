from django.contrib import admin
from .models import Notice, NoticeFile
# Register your models here.

admin.site.register(Notice)
admin.site.register(NoticeFile)