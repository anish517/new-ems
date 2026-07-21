import nepali_datetime
from typing import Any
from django.db.models.query import QuerySet
from django.forms import BaseModelForm
from django.http import HttpResponse, Http404
from django.shortcuts import redirect
from django.contrib import messages
from django.urls import reverse, reverse_lazy
from django.views.generic import ListView, CreateView, UpdateView, DeleteView, TemplateView

from authorization.mixins import CompanyAdminRequiredMixin
from leave_management.utils import get_years_till_current
from organization.models import Employee

from .forms import SalaryTransactionForm, SalaryTransactionReviewForm
from .models import Salary, SalaryTransaction
from .utils import get_average_salary, get_total_salary, get_net_salary_list

# Create your views here.


class AdminDashboard(CompanyAdminRequiredMixin, TemplateView):
    template_name = 'salary_management/admin_dashboard.html'
    fallback_url = reverse_lazy('salary_management:employee_dashboard')

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        np_date = nepali_datetime.date.today()
        context = super().get_context_data(**kwargs)
        organization = self.request.user.employee.organization
        context['employees'] = organization.employees
        context['average_salary'] = get_average_salary(
            organization=organization)
        context['total_salary'] = get_total_salary(organization=organization)
        context['net_salary_list'] = get_net_salary_list(
            organization=organization, year=np_date.year, month=np_date.month)
        context['breadcrumbs'] = [
            {'name': 'Salary mangement', 'url': ''}
        ]
        return context


class EmployeeDashboard(TemplateView):
    template_name = 'salary_management/employee_dashboard.html'

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
        employee_id = self.request.GET.get('employee', None)
        context['selected_year'] = self.request.GET.get(
            'year') and int(self.request.GET['year'])
        context['selected_month'] = self.request.GET.get('month')

        date_np = nepali_datetime.date.today()

        if context['selected_year'] and context['selected_year']:
            date_np = nepali_datetime.date(
                year=context['selected_year'], month=int(context['selected_month']), day=1)

        if employee_id is not None:
            try:
                employee = Employee.objects.get(id=employee_id)
            except Employee.DoesNotExist:
                raise Http404('Employee not found.')
        else:
            employee = self.request.user.employee

        context['employee'] = employee
        context['basic_salary'] = Salary.objects.get(
            employee=employee).basic_salary
        context['incentives'] = 10000
        context['gross_salary'] = Salary.calculate_gross_salary(
            employee=employee, year=date_np.year, month=date_np.month)
        context['net_salary'] = Salary.calculate_net_salary(
            employee=employee, year=date_np.year, month=date_np.month)
        context['transaction_history'] = SalaryTransaction.objects.filter(
            organization=employee.organization, salary__employee__id=employee.id).order_by('date')
        context['year_list'] = get_years_till_current(2050)
        context['year_list'].reverse()
        context['breadcrumbs'] = [
            {'name': 'Salary Tracker',
                'url': f"{reverse_lazy('salary_management:employee_dashboard')}"}
        ]
        return context


class SalaryListView(CompanyAdminRequiredMixin, ListView):
    model = Salary
    template_name = 'salary_management/salary_list.html'
    context_object_name = 'salary_list'

    def get_queryset(self) -> QuerySet[Salary]:
        if self.request.user.is_superuser:
            return Salary.objects.all()

        organization = self.request.user.employee.organization
        return Salary.objects.filter(organization=organization)

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['breadcrumbs'] = [
            {'name': 'Salary tracker', 'url': reverse(
                'salary_management:salary_list')},
        ]
        return context


def salary_update_view(request, id):
    if request.method == 'POST':
        try:
            salary = Salary.objects.get(id=id)
        except Salary.DoesNotExist:
            salary = None

        if salary:
            salary.ssf = float(request.POST.get('ssf'))
            salary.tds = float(request.POST.get('tds'))
            salary.epf = float(request.POST.get('epf'))
            salary.citizen_investment_trust = float(
                request.POST.get('citizen_investment_trust'))
            salary.insurance = float(request.POST.get('insurance'))
            salary.save()
            messages.success(
                request, f'Salary details of {salary.employee} updated successfully')
            return redirect('salary_management:salary_list')
        else:
            messages.error(request, "404 Not found")
            return redirect('salary_management:salary_list')


class SalaryTransactionListView(CompanyAdminRequiredMixin, ListView):
    model = SalaryTransaction
    template_name = 'salary_management/transaction_list.html'
    context_object_name = 'salary_transaction_list'
    fallback_url = reverse_lazy('salary_management:employee_dashboard')

    def get_queryset(self) -> QuerySet[SalaryTransaction]:
        employee = self.request.user.employee
        queryset = SalaryTransaction.objects.filter(
            organization=employee.organization)

        return queryset

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['form'] = SalaryTransactionForm(user=self.request.user)
        context['salary_transaction_review_form'] = SalaryTransactionReviewForm()
        context['year_list'] = get_years_till_current(2050)
        context['year_list'].reverse()
        selected_month = self.request.GET.get('month', None)
        selected_year = self.request.GET.get('year', None)

        if selected_month:
            context['selected_month'] = selected_month
        if selected_year:
            context['selected_year'] = int(selected_year)

        context['breadcrumbs'] = [
            {'name': 'Salary tracker', 'url': reverse(
                'salary_management:admin_dashboard')},
            {'name': 'Transactions', 'url': reverse(
                'salary_management:transaction_list_view')},
        ]
        return context


class SalaryTransactionCreateView(CompanyAdminRequiredMixin, CreateView):
    model = SalaryTransaction
    form_class = SalaryTransactionForm
    template_name = 'salary_management/transaction_create.html'
    success_url = 'salary_management:admin_dashboard'
    fallback_url = reverse_lazy('salary_management:employee_dashboard')

    def get_form_kwargs(self) -> dict[str, Any]:
        kwargs = super().get_form_kwargs()
        kwargs['user'] = self.request.user
        return kwargs

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object = form.save(commit=False)
        self.object.organization = self.request.user.employee.organization
        self.object.save()
        transaction_review_form = SalaryTransactionReviewForm(
            self.request.POST)

        if transaction_review_form.is_valid():
            transaction_review = transaction_review_form.save()
            transaction_review.organization = self.request.user.employee.organization
            transaction_review.employee = self.request.user.employee
            transaction_review.save()

        messages.success(self.request, 'Transaction saved successfully')
        return redirect(self.get_success_url())

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)

        context['breadcrumbs'] = [
            {'name': 'Salary management', 'url': reverse_lazy(
                'salary_management:admin_dashboard')},
            {'name': 'Transactions', 'url': reverse_lazy(
                'salary_management:transaction_list_view')},
            {'name': 'Add', 'url': ''}
        ]
        return context


class SalaryTransactionUpdateView(CompanyAdminRequiredMixin, UpdateView):
    model = SalaryTransaction
    form_class = SalaryTransactionForm
    template_name = 'salary_management/monthly_salary_transaction_update.html'
    success_url = 'salary_management:transaction_list_view'
    fallback_url = reverse_lazy('salary_management:employee_dashboard')

    def get_form_kwargs(self) -> dict[str, Any]:
        kwargs = super().get_form_kwargs()
        kwargs['user'] = self.request.user
        return kwargs

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        form.save()
        messages.success(self.request, 'Transaction updated successfully')
        return redirect(self.get_success_url())

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['salary_id'] = self.get_object().salary.id
        context['breadcrumbs'] = [
            {'name': 'Salary tracker', 'url': reverse(
                'salary_management:admin_dashboard')},
            {'name': 'Transactions', 'url': reverse(
                'salary_management:transaction_list_view')},
            {'name': 'Update', 'url': ''},
        ]
        return context


class SalaryTransactionDeleteView(CompanyAdminRequiredMixin, DeleteView):
    model = SalaryTransaction
    template_name = 'organization/delete_confirmation.html'
    success_url = reverse_lazy(
        'salary_management:transaction_list_view')
    fallback_url = reverse_lazy('salary_management:employee_dashboard')

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['cancel_redirect_url'] = self.get_success_url()
        return context
