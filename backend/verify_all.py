import django, os, sys
sys.path.insert(0,'.')
os.environ['DJANGO_SETTINGS_MODULE']='base.settings'
django.setup()

print('='*60)
print('1. SOFT DELETE VERIFICATION')
print('='*60)

from organization.models import Employee
active = Employee.objects.count()
all_emp = Employee.all_objects.count()
deleted = Employee.all_objects.filter(is_deleted=True).count()
print('Active employees (objects):', active)
print('Deleted employees:', deleted)
print('Total (all_objects):', all_emp)

if deleted > 0:
    del_emp = Employee.all_objects.filter(is_deleted=True).first()
    retrieved = Employee.all_objects.filter(pk=del_emp.pk).first()
    status = 'OK' if retrieved else 'FAIL'
    print('Retrieve deleted emp by ID', del_emp.pk, ':', status)

print()
print('='*60)
print('2. GLOBAL CALENDAR FILTER VERIFICATION')
print('='*60)

import nepali_datetime
from calendar_app.utilities import total_days_in_month

ny, nm = 2083, 4
start_m4 = nepali_datetime.date(ny, nm, 1)
end_m4 = nepali_datetime.date(ny, nm, total_days_in_month(ny, nm))
start_m3 = nepali_datetime.date(ny, 3, 1)
end_m3 = nepali_datetime.date(ny, 3, total_days_in_month(ny, 3))

from leave_management.models import LeaveRequest
leave_m4 = LeaveRequest.objects.filter(from_date__gte=start_m4, from_date__lte=end_m4).count()
leave_m3 = LeaveRequest.objects.filter(from_date__gte=start_m3, from_date__lte=end_m3).count()
print('Leave - Shrawan (month 4):', leave_m4)
print('Leave - Ashadh  (month 3):', leave_m3)

from task_management.models import Task
task_m4 = Task.objects.filter(planned_start_date__gte=start_m4, planned_start_date__lte=end_m4).count()
print('Tasks - Shrawan (month 4):', task_m4)

from attendance.models import Attendance
att_m4 = Attendance.objects.filter(date__gte=start_m4, date__lte=end_m4).count()
print('Attendance - Shrawan (month 4):', att_m4)

from noticeboard.models import Notice
notice_m4 = Notice.objects.filter(date__gte=start_m4, date__lte=end_m4).count()
print('Notices - Shrawan (month 4):', notice_m4)

from feedback.models import Complain
feedback_m4 = Complain.objects.filter(created_at__gte=start_m4, created_at__lte=end_m4).count()
print('Feedback - Shrawan (month 4):', feedback_m4)

from performance.models import PerformanceReview
perf_m4 = PerformanceReview.objects.filter(
    created_at__date__gte=start_m4.to_datetime_date(),
    created_at__date__lte=end_m4.to_datetime_date()
).count()
print('Performance - Shrawan (month 4):', perf_m4)

print()
print('='*60)
print('3. FILTER BACKEND VERIFICATION')
print('='*60)

from django.conf import settings
filter_backends = settings.REST_FRAMEWORK.get('DEFAULT_FILTER_BACKENDS', [])
has_global_filter = any('GlobalContextFilter' in fb for fb in filter_backends)
print('GlobalContextFilter active:', 'YES' if has_global_filter else 'NO')
print('Filter backends:', filter_backends)

print()
print('='*60)
print('4. SOFT DELETE MODEL COVERAGE')
print('='*60)
from django.apps import apps
soft_delete_models = []
for model in apps.get_models():
    if hasattr(model, 'is_deleted') and hasattr(model, 'all_objects'):
        soft_delete_models.append(model.__name__)
print('Models with soft delete:', sorted(set(soft_delete_models)))

print()
print('='*60)
print('5. EMPLOYEE VIEWSET QUERYSET FIX')
print('='*60)
from organization.api.views import EmployeeViewSet
has_class_queryset = hasattr(EmployeeViewSet, 'queryset') and EmployeeViewSet.__dict__.get('queryset') is not None
has_get_queryset = 'get_queryset' in EmployeeViewSet.__dict__
print('Has get_queryset (dynamic):', has_get_queryset)
print('retrieve uses all_objects: check get_queryset logic')

print()
print('ALL CHECKS COMPLETE')
