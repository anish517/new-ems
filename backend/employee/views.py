import nepali_datetime
from django.contrib import messages
from django.shortcuts import redirect
from django.urls import reverse_lazy
from django.views import generic

from organization.models import Address, Employee, NationalIdDetail

from .models import Contract
from .forms import ContractForm

# Create your views here.


class EmployeeDashboard(generic.TemplateView):
    template_name = 'employee/dashboard.html'


class ContractListView(generic.ListView):
    model = Contract
    template_name = 'employee/contract_list.html'
    context_object_name = 'contracts'

    def get_queryset(self):
        employee: Employee = self.request.user.employee
        if employee.is_company_admin():
            return Contract.objects.filter(organization=employee.organization)
        else:
            return Contract.objects.filter(organization=employee.organization)

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['breadcrumbs'] = [
            {'name': 'Contracts', 'url': reverse_lazy(
                'employee:contract_list')}
        ]
        return context


class ContractCreateView(generic.CreateView):
    model = Contract
    form_class = ContractForm
    template_name = 'employee/contract_create.html'

    def get_success_url(self):
        url = reverse_lazy('employee:contract_detail', kwargs={
                           'pk': self.object.pk})
        return url

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['breadcrumbs'] = [
            {'name': 'Contracts', 'url': reverse_lazy(
                'employee:contract_list')},
            {'name': 'Add', 'url': reverse_lazy('employee:contract_create')}
        ]
        return context

    def get_form_kwargs(self):
        kwargs = super().get_form_kwargs()
        kwargs['user'] = self.request.user
        return kwargs

    def form_valid(self, form):
        self.object = form.save(commit=False)
        self.object.organization = self.request.user.employee.organization
        self.object.save()
        messages.success(self.request, "Contract created successfully.")
        return redirect(self.get_success_url())


class ContractUpdateView(generic.UpdateView):
    model = Contract
    form_class = ContractForm
    template_name = 'employee/contract_update.html'

    def get_success_url(self):
        url = reverse_lazy('employee:contract_detail', kwargs={
                           'pk': self.get_object().pk})
        return url

    def form_valid(self, form):
        self.object = form.save()
        messages.success(self.request, "Contract updated successfully.")
        return redirect(self.get_success_url())

    def get_form_kwargs(self):
        kwargs = super().get_form_kwargs()
        kwargs['user'] = self.request.user
        return kwargs

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['breadcrumbs'] = [
            {'name': 'Contracts', 'url': reverse_lazy(
                'employee:contract_list')},
            {'name': 'Edit', 'url': reverse_lazy('employee:contract_update', kwargs={
                'pk': self.get_object().pk})}
        ]
        return context


class ContractDetailView(generic.DetailView):
    model = Contract
    template_name = 'employee/contract_detail.html'
    context_object_name = 'contract'

    def get_context_data(self, **kwargs):
        employee = self.get_object().employee
        context = super().get_context_data(**kwargs)
        context['employee'] = {
            'full_name': employee.user.full_name,
            'post': employee.post,
        }
        national_id_detail = NationalIdDetail.objects.filter(
            employee=employee)
        address = Address.objects.filter(employee=employee, type='permanent')
        if address.exists():
            context['employee']['address'] = address.first()

        if national_id_detail.exists():
            context['employee']['national_id_details'] = national_id_detail.first()

        context['is_expired'] = False

        if self.get_object().end_date < nepali_datetime.date.today():
            context['is_expired'] = True

        return context
