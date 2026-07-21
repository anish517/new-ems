import nepali_datetime
from typing import Any

from django.urls import reverse_lazy
from django.shortcuts import render, redirect
from django.views import generic, View
from django.contrib import messages
from django.contrib.auth import get_user_model, authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.contrib.auth.mixins import LoginRequiredMixin

from attendance.models import Attendance
from attendance.utils import average_working_hour, get_attendance, get_working_hour

from authorization.mixins import GuestOnlyMixin
from calendar_app.models import Category
from calendar_app.utilities import get_events
from employee.models import Contract
from leave_management.utils import get_employee_leave_request, get_years_till_current, get_employee_leave_days

from noticeboard.utils import get_notices
from organization.models import Department, Employee, EmployeeAnalysisReport, Organization, Post

from organization.utils import get_analysis_report
from salary_management.models import Salary

# Create your views here.

User = get_user_model()


class SignUpView(GuestOnlyMixin, View):
    def get(self, request):
        return render(request, 'authentication/signup.html')

    def post(self, request):
        organization_name = request.POST.get('organization_name')
        contact_person = request.POST.get('contact_person')
        email = request.POST.get('email')
        password = request.POST.get('password')

        user = User.objects.create_user(
            first_name=organization_name,
            last_name='',
            email=email,
            password=password
        )

        organization = Organization.objects.create(
            name=organization_name,
            contact_person=contact_person
        )
        department = Department.objects.create(
            organization=organization,
            department_name='admin',
        )
        post = Post.objects.create(department=department, title='Admin')
        Employee.objects.create(
            user=user,
            post=post
        )
        Category.objects.create(
            organization=organization,
            name='Birthday',
            color='info'
        )
        organization.admin_users.add(user)
        organization.save()

        messages.success(request, "Account was created successfully.")
        return redirect('authentication:signin')


def signin_view(request):
    if request.user.is_authenticated:
        return redirect('authentication:dashboard')

    if request.method == 'POST':
        email = request.POST.get('email')
        password = request.POST.get('password')
        user = authenticate(email=email, password=password)
        if user is not None:
            login(request, user)
            return redirect('home')
        else:
            messages.error(request, 'Invalid email or password.')
    return render(request, 'authentication/signin.html')


@login_required(login_url=reverse_lazy('authentication:signout'))
def signout_view(request):
    logout(request)
    return redirect('authentication:signin')


class Dashboard(LoginRequiredMixin, generic.TemplateView):
    template_name = 'authentication/dashboard.html'
    login_url = reverse_lazy('authentication:signin')

    def get_context_data(self, **kwargs) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        year: int = int(self.request.GET.get(
            'selected_year',  nepali_datetime.date.today().year))
        month: int = int(self.request.GET.get(
            'selected_month', nepali_datetime.date.today().month))

        employee: Employee = self.request.user.employee

        present_days = Attendance.get_no_of_present_days(
            employee=employee, year=year, month=month)
        context['leave_days'] = get_employee_leave_days(
            employee=employee, year=year, month=month)
        context['salary'] = Salary.calculate_net_salary(
            employee=employee, year=year, month=month)
        context['present_days'] = present_days
        context['working_hour'], context['working_hour_percentage'] = get_working_hour(
            employee=employee, year=year, month=month)
        context['average_working_hour'] = average_working_hour(
            employee=employee, year=year, month=month)
        context['attendance_list'] = get_attendance(
            employee=employee, year=year, month=month)
        context['leave_requests'] = get_employee_leave_request(
            employee=employee, year=year, month=month)
        context['events'] = get_events(year=year, month=month)
        context['notices'] = get_notices(
            organization=employee.organization, year=year, month=month)
        context['analyis_report'] = get_analysis_report(
            employee=employee, year=year, month=month)
        context['analysis_reports'] = EmployeeAnalysisReport.objects.filter(
            employee=employee).order_by('-date')
        context['has_checked_in_today'] = Attendance.has_checked_in_today(
            employee=employee)
        context['year_list'] = get_years_till_current(2060)
        context['year_list'].reverse()
        context['contract'] = Contract.objects.filter(
            employee=employee).order_by('-created_at').first()
        return context
