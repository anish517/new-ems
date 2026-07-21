import nepali_datetime

from typing import Any
from django.db.models.query import QuerySet
from django.forms import BaseModelForm
from django.urls import reverse, reverse_lazy
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse_lazy
from django.views.generic import ListView, DetailView, CreateView, UpdateView, DeleteView
from django.http import HttpRequest, HttpResponse
from django.contrib.auth import get_user_model
from django.contrib.auth.decorators import login_required
from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib import messages

from attendance.models import Attendance, RemoteWorkPermission
from attendance.utils import average_working_hour, get_attendance, get_working_hour
from authentication.form import AccountCreationForm
from authorization.mixins import CompanyAdminRequiredMixin
from calendar_app.utilities import get_events
from employee.models import Contract
from leave_management.utils import get_employee_leave_days, get_employee_leave_request, get_years_till_current
from noticeboard.utils import get_notices
from organization.utils import build_absolute_uri, get_analysis_report, send_welcome_email
from salary_management.models import Salary

from .forms import DepartmentForm, EmployeeForm, OrganizationFileForm, OrganizationFolderForm, OrganizationForm, PostForm

from .models import Address, BankDetail, Department, Employee, EmployeeAnalysisReport, EmployeeAnalysisReportFeedback, NationalIdDetail, Organization, OrganizationAddress, OrganizationFile, OrganizationFolder, OtherDocument, Post

# Create your views here.


class OrganizationCreateView(CreateView):
    model = Organization
    form_class = OrganizationForm
    template_name = 'organization/index.html'
    success_url = reverse_lazy('organization:detail')

    def form_valid(self, form):
        if form.is_valid():
            self.object = form.save()
            self.object.admin_users.add(self.request.user)
            self.object.save()
            OrganizationAddress.objects.create(
                organization=self.object,
                address_line_1=self.request.POST.get('address_line_1'),
                address_line_2=self.request.POST.get('address_line_2'),
                state=self.request.POST.get('state'),
                city=self.request.POST.get('city'),
                primary=True
            )
            # create management department and add the user as CEO of the company

            department = Department.objects.create(
                organization=self.object,
                department_name='Admin',
                department_lead=self.request.user,
            )
            post = Post.objects.create(
                department=department,
                title='Admin'
            )
            Employee.objects.create(
                user=self.request.user,
                post=post,
            )
            messages.success(
                self.request, "Organization was successfully created.")
            return redirect(self.success_url)
        else:
            return self.form_invalid(form)


class OrganizationListView(ListView):
    model = Organization
    template_name = 'organization/organization_list.html'
    context_object_name = 'organizations'

    def get_queryset(self) -> QuerySet[Organization]:
        if self.request.user.is_superuser:
            return Organization.objects.all()
        else:
            return Organization.objects.filter(admin_users=self.request.user)

    def get(self, request: HttpRequest, *args: Any, **kwargs: Any) -> HttpResponse:
        if request.user.is_superuser:
            return super().get(request, *args, **kwargs)
        else:
            messages.error(request, 'Unauthorized')
            return redirect('authentication:dashboard')


class OrganizationUpdateView(CompanyAdminRequiredMixin, UpdateView):
    model = Organization
    form_class = OrganizationForm
    template_name = 'organization/index.html'
    fallback_url = reverse_lazy('authentication:dashboard')

    def get_success_url(self) -> str:
        url = reverse_lazy('organization:detail')
        return url

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object = form.save()
        address_id = self.request.POST.get('address_id', None)
        if address_id:
            address = OrganizationAddress.objects.get(id=address_id, )
            address.address_line_1 = self.request.POST.get(
                'address_line_1', '')
            address.address_line_2 = self.request.POST.get(
                'address_line_2', '')
            address.state = self.request.POST.get('state', '')
            address.city = self.request.POST.get('city', '')
            address.latitude = self.request.POST.get('latitude', '')
            address.longitude = self.request.POST.get('longitude', '')
            address.save()

        return redirect(self.get_success_url())


class OrganizationDetailView(CompanyAdminRequiredMixin, DetailView):
    model = Organization
    template_name = 'organization/basic_information.html'
    context_object_name = 'organization'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        obj = self.get_object()
        form = OrganizationForm(instance=obj)
        try:
            context['primary_address'] = OrganizationAddress.objects.get(
                organization=obj, primary=True)
        except OrganizationAddress.DoesNotExist:
            context['primary_address'] = OrganizationAddress.objects.create(
                address_line_1='',
                address_line_2='',
                city='',
                state='',
                organization=obj,
                primary=True
            )
        context['form'] = form
        context['department_form'] = DepartmentForm(user=self.request.user)
        context['posts'] = self.request.user.employee.organization.posts
        context['breadcrumbs'] = [
            {'name': 'Organization', 'url': reverse('organization:detail')},
            {'name': 'Overview', 'url': '#'}
        ]
        return context

    def get_object(self):
        obj = self.request.user.employee.organization
        return obj


class DepartmentListView(CompanyAdminRequiredMixin, ListView):
    model = Department
    template = 'organization/department_list.html'
    context_object_name = 'department_list'

    def get_queryset(self) -> QuerySet[Department]:
        if self.request.user.is_superuser:
            return Department.objects.all()
        return self.request.user.employee.organization.departments

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['department_form'] = DepartmentForm(user=self.request.user)
        context['breadcrumbs'] = [
            {'name': 'Organization', 'url': reverse('organization:detail')},
            {'name': 'Departments', 'url': reverse(
                'organization:department_list')}
        ]
        return context


class DepartmentCreateView(CompanyAdminRequiredMixin, CreateView):
    model = Department
    template_name = 'organization/index.html'
    success_url = reverse_lazy('organization:department_list')
    form_class = DepartmentForm

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object = form.save()
        self.object.organization = self.request.user.employee.organization
        self.object.save()

        return redirect(self.success_url)

    def get_form_kwargs(self):
        kwargs = super().get_form_kwargs()
        kwargs['user'] = self.request.user
        return kwargs


class DepartmentDetailView(CompanyAdminRequiredMixin, DetailView):
    model = Department
    queryset = Department.objects.all()
    template_name = 'organization/department_detail.html'
    context_object_name = 'department'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['page_title'] = 'Department details'
        context['breadcrumbs'] = [
            {'name': 'Organization', 'url': reverse('organization:detail')},
            {'name': 'Departments', 'url': reverse(
                'organization:department_list')},
            {'name': 'Detail', 'url': reverse('organization:department_detail', kwargs={
                                              'pk': self.get_object().pk})}

        ]
        return context


class DepartmentDeleteView(CompanyAdminRequiredMixin, DeleteView):
    model = Department
    template_name = 'organization/delete_confirmation.html'
    success_url = reverse_lazy('organization:department_list')

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['cancel_redirect_url'] = self.get_success_url()
        context['breadcrumbs'] = [
            {'name': 'Organization', 'url': reverse('organization:detail')},
            {'name': 'Departments', 'url': reverse(
                'organization:department_list')},
            {'name': 'Delete', 'url': '#'},
        ]
        return context


class PostCreateView(CompanyAdminRequiredMixin, CreateView):
    model = Post
    template_name = 'organization/designation_list.html'
    success_url = reverse_lazy('organization:post_list')

    def get_form(self) -> BaseModelForm:
        form = PostForm(user=self.request.user, data=self.request.POST or None)
        return form


class PostListView(CompanyAdminRequiredMixin, ListView):
    model = Post
    template_name = 'organization/designation_list.html'
    context_object_name = 'designation_list'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['post_form'] = PostForm(user=self.request.user)
        context['breadcrumbs'] = [
            {'name': 'Organization', 'url': reverse('organization:detail')},
            {'name': 'Designations', 'url': '#'},
        ]
        return context

    def get_queryset(self) -> QuerySet[Post]:
        if self.request.user.is_superuser:
            return Post.objects.all()
        return self.request.user.employee.organization.posts


class PostDeleteView(CompanyAdminRequiredMixin, DeleteView):
    model = Post
    template_name = 'organization/delete_confirmation.html'
    success_url = reverse_lazy('organization:post_list')

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['cancel_redirect_url'] = reverse_lazy('organization:post_list')
        context['breadcrumbs'] = [
            {'name': 'Organization', 'url': reverse('organization:detail')},
            {'name': 'Designations', 'url': reverse('organization:post_list')},
            {'name': 'Delete', 'url': '#'},
        ]
        return context


class EmployeeListView(CompanyAdminRequiredMixin, ListView):
    model = Employee
    template_name = 'organization/employee_list.html'
    context_object_name = 'employee_list'

    def get_queryset(self) -> QuerySet:
        status = self.request.GET.get('status', None)
        if status == 'active' or status == None:
            if self.request.user.is_superuser:
                return Employee.objects.filter(is_active=True)
            return self.request.user.employee.organization.employees.filter(is_active=True)
        else:
            if self.request.user.is_superuser:
                return Employee.objects.filter(is_active=False)
            return self.request.user.employee.organization.employees.filter(is_active=False)

    def get_context_data(self, **kwargs) -> dict:
        context = super().get_context_data(**kwargs)
        context['page_title'] = 'Employees'
        context['breadcrumbs'] = [
            {'name': 'Organization', 'url': reverse('organization:detail')},
            {'name': 'Employees', 'url': '#'},
        ]
        return context


class EmployeeCreateView(CompanyAdminRequiredMixin, CreateView):
    model = get_user_model()
    form_class = AccountCreationForm
    template_name = 'organization/employee_create.html'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['posts'] = self.request.user.employee.post.department.organization.posts
        return context

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object = form.save()
        post = Post.objects.get(id=self.request.POST.get('post'))
        basic_salary = self.request.POST.get('basic_salary')
        employee = Employee.objects.create(
            user=self.object,
            post=post,
            basic_salary=basic_salary,
        )
        messages.success(self.request, 'Employee added successfully')
        relative_redirect_link = reverse_lazy('authentication:dashboard')
        redirect_link = build_absolute_uri(
            self.request, relative_redirect_link)
        send_welcome_email(employee, redirect_link)
        return redirect(self.get_success_url())

    def get_success_url(self) -> str:
        employee = Employee.objects.get(user=self.object)
        return reverse_lazy('organization:employee_detail', kwargs={'pk': employee.id})


class EmployeeDetailView(CompanyAdminRequiredMixin, DetailView):
    model = Employee
    template_name = 'organization/employee_detail.html'

    def get_context_data(self, **kwargs) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        year: int = int(self.request.GET.get(
            'selected_year',  nepali_datetime.date.today().year))
        month: int = int(self.request.GET.get(
            'selected_month', nepali_datetime.date.today().month))

        employee: Employee = Employee.objects.get(id=self.kwargs.get('pk'))
        context['employee'] = employee
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
        context['breadcrumbs'] = [
            {'name': 'Organization', 'url': reverse('organization:detail')},
            {'name': 'Employees', 'url': reverse(
                'organization:employee_list')},
            {'name': 'Detail', 'url': '#'},
        ]
        return context


class EmployeeUpdateView(UpdateView):
    model = Employee
    form_class = EmployeeForm
    context_object_name = 'employee'
    template_name = 'organization/employee_update.html'

    def dispatch(self, request, *args, **kwargs):
        employee: Employee = request.user.employee
        if employee == self.get_object() or employee.is_company_admin():
            return super().dispatch(request, *args, **kwargs)
        else:
            return HttpResponse("Unauthorized")

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['posts'] = self.request.user.employee.post.department.organization.posts
        context['temporary_address'] = Address.objects.filter(
            employee=self.get_object(), type='temporary').first()
        context['permanent_address'] = Address.objects.filter(
            employee=self.get_object(), type='permanent').first()
        context['national_id'] = NationalIdDetail.objects.filter(
            employee=self.get_object()).first()
        context['bank_detail'] = BankDetail.objects.filter(
            employee=self.get_object()).first()
        context['salary'] = self.get_object().salary
        try:
            context['remote_work_permission'] = self.get_object(
            ).remote_work_permission
        except Exception as e:
            context['remote_work_permission'] = RemoteWorkPermission.objects.create(
                employee=self.get_object())
        context['breadcrumbs'] = [
            {'name': 'Organization', 'url': reverse('organization:detail')},
            {'name': 'Employees', 'url': reverse(
                'organization:employee_list')},
            {'name': 'Detail', 'url': reverse('organization:employee_detail', kwargs={
                                              'pk': self.get_object().pk})},
            {'name': 'Edit', 'url': ''},
        ]
        return context

    def get_success_url(self) -> str:
        return reverse_lazy('organization:employee_update', kwargs={'pk': self.object.pk})


def employee_delete_view(request, pk):
    employee = Employee.objects.get(pk=pk)

    if not employee.is_company_admin():
        messages.error("Unauthorized")
        return redirect('authentication:dashboard')
    if request.method == 'POST':
        employee.is_active = False
        employee.user.is_active = False
        employee.user.save()
        employee.save()
        messages.success(request, 'Employee removed successfully.')
        return redirect('organization:employee_list')

    context = {
        'cancel_redirect_url': reverse_lazy('organization:employee_list'),
        'breadcrumbs': [
            {'name': 'Organization', 'url': reverse('organization:detail')},
            {'name': 'Employees', 'url': reverse(
                'organization:employee_list')},
            {'name': 'Delete', 'url': '#'},
        ]
    }

    return render(request, 'organization/delete_confirmation.html', context=context)


def employee_undo_delete(request, pk):
    employee = Employee.objects.get(pk=pk)
    employee.is_active = True
    employee.user.is_active = True
    employee.user.save()
    employee.save()
    messages.success(request, 'Deleted employee recovered successfully')
    return redirect('organization:employee_list')


class AnalysisReportList(DetailView):
    model = Employee
    template_name = 'organization/analysis_report_list.html'
    context_object_name = 'employee'

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['analysis_report_list'] = EmployeeAnalysisReport.objects.filter(
            employee=self.get_object())
        print(context)
        return context


def create_analyis_report_feedback(request):
    if request.method == 'POST':
        report = EmployeeAnalysisReport.objects.get(
            id=request.POST.get('report_id'))
        employee = request.user.employee
        content = request.POST.get('feedback')
        if report.employee == employee or request.user.employee.is_company_admin():
            report_feedback = EmployeeAnalysisReportFeedback.objects.create(
                report=report,
                employee=employee,
                content=content
            )
            return redirect(request.META.get('HTTP_REFERER', '/'))
    else:
        messages.error(request, 'Unauthorized')
        return redirect('authentication:dashboard')


def delete_analysis_report_feedback(request, pk):
    if request.method == 'POST':
        report_feedback = EmployeeAnalysisReportFeedback.objects.get(pk=pk)
        if report_feedback.employee.user == request.user:
            report_feedback.delete()
            return redirect(request.META.get('HTTP_REFERER', '/'))
    else:
        messages.error(request, 'Unauthorized')
        return redirect('authentication:dashboard')


class OrganizationFolderListView(LoginRequiredMixin, ListView):
    model = OrganizationFolder
    template_name = 'organization/organization_folder_list.html'
    context_object_name = 'folder_list'

    def get_queryset(self) -> QuerySet[OrganizationFolder]:
        if self.request.user.is_superuser:
            return OrganizationFolder.objects.all()
        return OrganizationFolder.objects.filter(organization=self.request.user.employee.organization)

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['new_folder_form'] = OrganizationFolderForm()
        return context


class OrganizationFolderCreateView(LoginRequiredMixin, CreateView):
    model = OrganizationFolder
    template_name = 'organization/organization_folder_list.html'
    form_class = OrganizationFolderForm
    success_url = reverse_lazy('organization:folder_list')

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object = form.save()
        self.object.organization = self.request.user.employee.organization
        self.object.save()
        messages.success(self.request, 'Folder created successfully.')
        return redirect(self.get_success_url())

    def form_invalid(self, form: BaseModelForm) -> HttpResponse:
        print(form.errors)
        return super().form_invalid(form)


class OrganizationFolderDetailView(LoginRequiredMixin, DetailView):
    model = OrganizationFolder
    template_name = 'organization/organization_folder_list.html'
    context_object_name = 'folder'

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['file_form'] = OrganizationFileForm()
        return context


class OrganizationFileCreateView(LoginRequiredMixin, CreateView):
    model = OrganizationFile
    form_class = OrganizationFileForm
    template_name = 'organization/organization_folder_list.html'

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object = form.save(commit=False)
        self.object.organization = self.request.user.employee.organization
        self.object.folder = get_object_or_404(
            OrganizationFolder, pk=self.kwargs['pk'])
        self.object.save()
        messages.success(self.request, 'File saved successfully')
        return redirect(self.get_success_url())

    def get_success_url(self) -> str:
        return reverse_lazy('organization:folder_detail', kwargs={'pk': self.kwargs['pk']})


class OrganizationFileDeleteView(LoginRequiredMixin, DeleteView):
    model = OrganizationFile
    template_name = 'organization/delete_confirmation.html'

    def get_success_url(self) -> str:
        obj = self.get_object()
        folder_id = obj.folder.pk
        return reverse_lazy('organization:folder_detail', kwargs={'pk': folder_id})

    def get_context_data(self, **kwargs) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['cancel_redirect_url'] = self.get_success_url()
        return context


@login_required
def organization_policies_list_view(request):
    organization = request.user.employee.organization
    folder = OrganizationFolder.objects.get(
        organization=organization, title='Policies')
    context = {
        'folder': folder
    }
    return render(request, 'organization/policies_list.html', context=context)
