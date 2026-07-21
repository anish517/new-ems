from typing import Any
from django.db.models.query import QuerySet
from django.shortcuts import redirect, render
from django.urls import reverse, reverse_lazy
from django.views import generic
from django.contrib import messages
from nepali_datetime import datetime

from attendance.filter import AttendanceFilter
from authorization.mixins import CompanyAdminRequiredMixin
from leave_management.utils import get_employees_on_leave
from organization.models import Employee
from .models import Attendance, CheckInOut
from .utils import get_absent_employees, get_attendance, get_checked_employees, get_employees_attendance_list, get_working_hour


# Create your views here.

class AdminDashboard(CompanyAdminRequiredMixin, generic.TemplateView):
    template_name = 'attendance/admin_dashboard.html'
    fallback_url = reverse_lazy('attendance:employee_dashboard')

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        employee: Employee = self.request.user.employee
        context = super().get_context_data(**kwargs)
        context["checked_in_attendances"] = get_checked_employees(
            organization=employee.organization)
        context['employees_on_leave'] = get_employees_on_leave(
            organization=employee.organization)
        context['absent_employees'] = get_absent_employees(
            organization=employee.organization)
        context['employee_attendance'] = get_employees_attendance_list(
            organization=employee.organization)
        context['breadcrumbs'] = [
            {'name': 'Attendance', 'url': ''},
        ]
        return context


class EmployeeDashboard(generic.TemplateView):
    template_name = 'attendance/employee_dashboard.html'

    def dispatch(self, request, *args, **kwargs):
        employee_id = self.request.GET.get(
            'employee', self.request.user.employee.id)
        employee = Employee.objects.get(id=employee_id)

        if self.request.user.employee == employee or self.request.user.employee.is_company_admin():
            return super().dispatch(request, *args, **kwargs)
        else:
            messages.error(request, "Unauthorized")
            return redirect('authentication:dashboard')

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        employee_id = self.request.GET.get(
            'employee', self.request.user.employee.id)
        employee = Employee.objects.get(id=employee_id)
        context['employee'] = employee
        context['check_in_time'] = Attendance.check_in_time(employee=employee)
        context['working_hour'], context['shift_covered'] = get_working_hour(
            employee=employee)
        context['has_checked_in_today'] = Attendance.has_checked_in_today(
            employee=employee)
        context['attendance_history'] = get_attendance(employee=employee)
        context['breadcrumbs'] = [
            {'name': 'Attendance', 'url': ''}
        ]
        return context


def attendance_list(request):
    employee: Employee = request.user.employee
    if employee.is_company_admin():
        attendance_qs = Attendance.objects.filter(
            organization=employee.organization)
    else:
        attendance_qs = Attendance.objects.filter(employee=employee)

    attendance_filter = AttendanceFilter(
        request.GET, queryset=attendance_qs, user=request.user
    )
    filtered_qs = attendance_filter.qs.order_by('-date')
    context = {
        'attendances': filtered_qs,
        'filter': attendance_filter,
    }
    return render(request, 'attendance/attendance_list.html', context=context)


def check_in(request):
    try:
        check_in = Attendance.check_in(request.user.employee)
        messages.success(
            request, f'Checked in at {check_in.check_in.strftime("%I:%M %p")}')
    except ValueError as e:
        messages.error(request, f"{e}")

    return redirect('attendance:employee_dashboard')


def check_out(request):
    try:
        check_out = Attendance.check_out(request.user.employee)
        messages.success(
            request, f'Checked out at {check_out.check_out.strftime("%I:%M %p")}')
    except ValueError as e:
        messages.error(request, f"{e}")

    return redirect('attendance:employee_dashboard')


def update_last_check_out(request, id):
    organization_admins = request.user.employee.organization.admin_users.all()
    if request.method == "POST" and request.user in organization_admins:
        last_check_out_time_str = request.POST.get("last_check_out")
        if last_check_out_time_str:
            last_check_out_time = datetime.strptime(
                last_check_out_time_str, "%H:%M"
            ).time()
            try:
                attendance = Attendance.objects.get(id=id)
                last_check_in_out = CheckInOut.objects.get(
                    attendance=attendance, check_out=None
                )
            except:
                last_check_in_out = None

            if last_check_in_out and attendance:

                last_check_in_out.check_out = last_check_out_time
                last_check_in_out.save()
                messages.success(
                    request, "Last checkout time updated successfully")
            else:
                messages.error(request, "404 Not Found")
        else:
            messages.error(request, "Invalid time")
    else:
        messages.error(request, "Unauthorized")
    return redirect(
        "attendance:employee_attendance_detail", employee_id=attendance.employee.id
    )
