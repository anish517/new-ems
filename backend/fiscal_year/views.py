from typing import Any
from django.db.models.query import QuerySet
from django.forms import BaseModelForm
from django.http import HttpResponse
from django.shortcuts import redirect
from django.urls import reverse_lazy
from django.contrib import messages
from django.views.generic import ListView, CreateView, UpdateView

from authorization.mixins import CompanyAdminRequiredMixin

from .forms import FiscalYearForm
from .models import FiscalYear

# Create your views here.


class FiscalYearListView(CompanyAdminRequiredMixin, ListView):
    model = FiscalYear
    template_name = 'fiscal_year/fiscal_year_list.html'
    context_object_name = 'fiscal_year_list'

    def get_queryset(self) -> QuerySet[FiscalYear]:
        return FiscalYear.objects.filter(organization=self.request.user.employee.organization)

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['form'] = FiscalYearForm()
        return context


class FiscalYearCreateView(CompanyAdminRequiredMixin, CreateView):
    model = FiscalYear
    form_class = FiscalYearForm
    template_name = 'fiscal_year/fiscal_year_list.html'
    success_url = reverse_lazy('fiscal_year:list')

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object = form.save()
        self.object.organization = self.request.user.employee.organization
        self.object.save()
        messages.success(self.request, 'New fiscal year created successfully')
        return redirect(self.get_success_url())


class FiscalYearUpdateView(CompanyAdminRequiredMixin, UpdateView):
    model = FiscalYear
    form_class = FiscalYearForm
    success_url = reverse_lazy('fiscal_year:list')
