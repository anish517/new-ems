import nepali_datetime
from typing import Any
from django.contrib import messages
from django.db.models.query import QuerySet
from django.forms import BaseModelForm
from django.http import HttpResponse
from django.shortcuts import redirect, render
from django.urls import reverse, reverse_lazy
from django.views import generic, View
from django_filters.views import FilterView

from authorization.mixins import CompanyAdminRequiredMixin, OwnerAndAdminOnlyMixin
from leave_management.filters import LeaveRequestFilter
from leave_management.utils import (
    get_leave_balance_by_employee,
)

from organization.models import Employee

from .form import LeaveRequestForm, LeaveTypeForm
from .models import LeaveRequest, LeaveRequestFiles, LeaveType, LeaveBalance

# Create your views here.


class AdminDashboard(CompanyAdminRequiredMixin, generic.TemplateView):
    template_name = 'leave_management/admin_dashboard.html'
    fallback_url = reverse_lazy('leave_management:employee_dashboard')

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        selected_year = int(self.request.GET.get(
            'year', nepali_datetime.date.today().year))
        employee: Employee = self.request.user.employee
        context = super().get_context_data(**kwargs)
        context['leave_types'] = LeaveType.objects.filter(
            organization=employee.organization).order_by('name')
        context['leave_types_header'] = context['leave_types'][0:2]
        context['leave_balances_by_employee'] = get_leave_balance_by_employee(
            organization=employee.organization)

        leave_requests_qs = LeaveRequest.objects.filter(
            organization=employee.organization)

        selected_year_leave_requests = [
            leave_request.id for leave_request in leave_requests_qs if leave_request.created_at.year == selected_year]

        leave_requests_qs = LeaveRequest.objects.filter(
            id__in=selected_year_leave_requests)

        context['employee'] = employee
        context['all_leave_requests'] = leave_requests_qs
        context['leave_approvals'] = leave_requests_qs.filter(
            is_reviewed=False).order_by('created_at')
        context['leave_history'] = leave_requests_qs.filter(
            is_reviewed=True).order_by('-created_at')
        context['approved_leave_requests'] = leave_requests_qs.filter(
            is_reviewed=True, is_approved=True)
        context['declined_leave_requests'] = leave_requests_qs.filter(
            is_reviewed=True, is_approved=False)

        context['breadcrumbs'] = [
            {'name': 'Leave tracker', 'url': ''}
        ]
        return context


class EmployeeDashboard(generic.TemplateView):
    template_name = 'leave_management/employee_dashboard.html'
    fallback_url = reverse_lazy('leave_management:employee_dashboard')

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
        selected_year = int(self.request.GET.get(
            'year', nepali_datetime.date.today().year))
        employee = Employee.objects.get(id=employee_id)

        leave_requests_qs = LeaveRequest.objects.filter(
            organization=employee.organization, employee=employee)

        selected_year_leave_requests = [
            leave_request.id for leave_request in leave_requests_qs if leave_request.created_at.year == selected_year]

        leave_requests_qs = LeaveRequest.objects.filter(
            id__in=selected_year_leave_requests)

        context['employee'] = employee
        context['all_leave_requests'] = leave_requests_qs
        context['leave_approvals'] = leave_requests_qs.filter(
            is_reviewed=False).order_by('created_at')
        context['leave_history'] = leave_requests_qs.filter(
            is_reviewed=True).order_by('-created_at')
        context['approved_leave_requests'] = leave_requests_qs.filter(
            is_reviewed=True, is_approved=True)
        context['leave_balances_by_employee'] = LeaveBalance.objects.filter(
            organization=employee.organization, employee=employee)
        context['breadcrumbs'] = [
            {'name': 'Leave tracker', 'url': ''}
        ]
        return context


def leave_request_list(request):
    employee: Employee = request.user.employee
    if employee.is_company_admin():
        queryset = LeaveRequest.objects.filter(
            organization=request.user.employee.organization)
    else:
        queryset = LeaveRequest.objects.filter(
            organization=request.user.employee.organization, employee=employee)

    leave_request_filter = LeaveRequestFilter(
        request.GET, queryset=queryset)
    filtered_leave_requests = leave_request_filter.qs
    context = {
        'leave_requests': filtered_leave_requests,
        'filter': leave_request_filter,
    }

    if employee.is_company_admin():
        context['breadcrumbs'] = [
            {'name': 'Leave tracker', 'url': reverse_lazy(
                'leave_management:admin_dashboard')},
            {'name': 'Leave requests', 'url': ''}
        ]
    else:
        context['breadcrumbs'] = [
            {'name': 'Leave tracker', 'url': reverse_lazy(
                'leave_management:employee_dashboard')},
            {'name': 'Leave requests', 'url': ''}
        ]
    return render(request, 'leave_management/leave_request_list.html', context)


class CreateLeaveRequest(generic.CreateView):
    model = LeaveRequest
    form_class = LeaveRequestForm
    template_name = "leave_management/leave_request_form.html"

    def get_success_url(self) -> str:
        return reverse_lazy('leave_management:employee_dashboard')

    def get_form_kwargs(self):
        kwargs = super().get_form_kwargs()
        kwargs["user"] = self.request.user
        return kwargs

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context["breadcrumbs"] = [
            {
                "name": "My leave requests",
                "url": reverse("leave_management:employee_dashboard"),
            },
            {"name": "Apply leave", "url": reverse(
                "leave_management:apply_leave")},
        ]
        return context

    def form_valid(self, form):
        self.object = form.save(commit=False)
        self.object.employee = self.request.user.employee
        self.object.organization = self.request.user.employee.organization
        self.object.created_at = nepali_datetime.date.today()
        self.object.save()
        messages.success(self.request, "Leave requested successfully.")
        return redirect(self.get_success_url())

    def form_invalid(self, form):
        # If the form is invalid, re-render the form with errors and messages
        return self.render_to_response(self.get_context_data(form=form))


class LeaveRequestDetail(OwnerAndAdminOnlyMixin, generic.DetailView):
    model = LeaveRequest
    template_name = 'leave_management/leave_request_detail.html'
    context_object_name = 'leave_request'
    fallback_url = reverse_lazy('leave_management:employee_dashboard')

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        employee: Employee = self.request.user.employee

        if employee.is_company_admin():
            context['breadcrumbs'] = [
                {'name': 'Salary tracker', 'url': reverse(
                    'leave_management:admin_dashboard')},
                {'name': 'Leave detail', 'url': ''},
            ]
        else:
            context['breadcrumbs'] = [
                {'name': 'Salary tracker', 'url': reverse(
                    'leave_management:employee_dashboard')},
                {'name': 'Leave detail', 'url': ''},
            ]
        return context


def approve_leave_request(request, leave_request_id):
    if request.method == "POST":
        action = request.POST.get("action", None)
        leave_request = LeaveRequest.objects.get(id=leave_request_id)

        if action == 'approve_as_paid':
            leave_request.is_approved = True
            leave_request.is_paid = True
            messages.success(request, "Leave request approved as paid leave")

        elif action == 'approve_as_unpaid':
            leave_request.is_approved = True
            leave_request.is_paid = False
            messages.success(request, "Leave request approved as unpaid leave")

        else:
            leave_request.is_approved = False
            leave_request.is_paid = False
            messages.success(request, "Leave request declined")
        leave_request.is_reviewed = True
        leave_request.save()
        return redirect("leave_management:admin_dashboard")
    else:
        return HttpResponse("Method not allowed")


class LeaveBalanceList(CompanyAdminRequiredMixin, generic.TemplateView):
    template_name = 'leave_management/leave_balance_list.html'
    fallback_url = reverse_lazy('leave_management:employee_dashboard')

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        employee = self.request.user.employee
        context = super().get_context_data(**kwargs)
        context['leave_types'] = LeaveType.objects.filter(
            organization=employee.organization).order_by('name')[0:2]
        context['leave_balances_by_employee'] = get_leave_balance_by_employee(
            organization=employee.organization)
        context["breadcrumbs"] = [
            {"name": "Leave tracker", "url": reverse(
                "leave_management:admin_dashboard")},
            {"name": "Leave balance", "url": reverse(
                "leave_management:leave_balance_list")},
        ]
        return context


class LeaveBalanceUpdateView(CompanyAdminRequiredMixin, View):
    fallback_url = reverse_lazy('leave_management:employee_dashboard')

    def get(self, request, employee_id):
        employee = Employee.objects.get(id=employee_id)
        leave_balances = LeaveBalance.objects.filter(employee=employee)
        context = {
            'employee': employee,
            'leave_balances': leave_balances,
        }
        context['breadcrumbs'] = [
            {'name': 'Leave tracker',
                'url': reverse_lazy('leave_management:admin_dashboard')},
            {'name': 'Leave balance', 'url': reverse_lazy(
                'leave_management:leave_balance_list')},
            {'name': f'{employee.user.full_name}', 'url': ''}
        ]
        return render(request, 'leave_management/leave_balance_edit.html', context=context)


class LeaveTypeList(CompanyAdminRequiredMixin, generic.ListView):
    model = LeaveType
    template_name = "leave_management/leave_type_list.html"
    context_object_name = "leave_type_list"

    def get_context_data(self, **kwargs) -> dict:
        context = super().get_context_data(**kwargs)
        context["leave_type_form"] = LeaveTypeForm()
        context["breadcrumbs"] = [
            {"name": "Leave tracker", "url": reverse(
                "leave_management:admin_dashboard")},
            {"name": "Leave types", "url": reverse(
                "leave_management:leave_type_list")},
        ]
        return context

    def get_queryset(self) -> QuerySet[LeaveType]:
        if self.request.user.is_superuser:
            return LeaveType.objects.all()
        return LeaveType.objects.filter(
            organization=self.request.user.employee.organization
        )


class CreateLeaveType(CompanyAdminRequiredMixin, generic.CreateView):
    model = LeaveType
    template_name = "leave_management/leave_type_list.html"
    form_class = LeaveTypeForm
    success_url = "leave_management:leave_type_list"

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object = form.save(commit=False)
        self.object.organization = self.request.user.employee.organization
        self.object.save()
        messages.success(self.request, "New leave type added successfully")
        return redirect(self.success_url)


class UpdateLeaveType(CompanyAdminRequiredMixin, generic.UpdateView):
    model = LeaveType
    template_name = "leave_management/leave_type_list.html"
    form_class = LeaveTypeForm
    success_url = reverse_lazy("leave_management:leave_type_list")
