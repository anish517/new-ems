from typing import Any
from django.db.models.query import QuerySet
import nepali_datetime
from django.forms import BaseModelForm
from django.http import HttpResponse
from django.shortcuts import render, redirect
from django.urls import reverse_lazy
from django.views import generic
from django.contrib import messages

from authorization.mixins import CompanyAdminRequiredMixin
from organization.models import Employee
from .models import Notice, NoticeFile
from .forms import NoticeForm
# Create your views here.


class Dashboard(generic.TemplateView):
    template_name = 'noticeboard/dashboard.html'

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        employee: Employee = self.request.user.employee
        context['notices'] = Notice.objects.filter(
            organization=employee.organization)
        context['breadcrumbs'] = [
            {'name': 'Noticeboard', 'url': reverse_lazy(
                'noticeboard:dashboard')}
        ]
        return context


class CreateNoticeView(CompanyAdminRequiredMixin, generic.CreateView):
    model = Notice
    form_class = NoticeForm
    template_name = 'noticeboard/notice_create.html'
    success_url = reverse_lazy('noticeboard:dashboard')
    fallback_url = reverse_lazy('noticeboard:dashboard')

    def get_context_data(self, **kwargs) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['breadcrumbs'] = [
            {'name': 'Notices', 'url': reverse_lazy(
                'noticeboard:notice_list')},
            {'name': 'create', 'url': '#'},
        ]
        return context

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object = form.save()
        self.object.organization = self.request.user.employee.organization
        self.object.created_by = self.request.user.employee
        self.object.created_at = nepali_datetime.date.today()
        self.object.save()

        files = self.request.FILES.getlist('files')
        for file in files:
            NoticeFile.objects.create(
                notice=self.object,
                file=file
            )

        messages.success(self.request, f'Notice created successfully')
        return redirect(self.get_success_url())


class NoticeListView(generic.ListView):
    model = Notice
    template_name = 'noticeboard/notice_list.html'
    context_object_name = 'notices'

    def get_queryset(self) -> QuerySet[Notice]:
        return Notice.objects.filter(organization=self.request.user.employee.organization).order_by('-created_at')

    def get_context_data(self, **kwargs) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['breadcrumbs'] = [
            {'name': 'Notices', 'url': reverse_lazy(
                'noticeboard:notice_list')},
        ]
        return context


class NoticeUpdateView(CompanyAdminRequiredMixin, generic.UpdateView):
    model = Notice
    form_class = NoticeForm
    template_name = 'noticeboard/notice_update.html'
    success_url = reverse_lazy('noticeboard:dashboard')
    fallback_url = reverse_lazy('noticeboard:dashboard')

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object = form.save()
        self.object.organization = self.request.user.employee.organization
        self.object.created_by = self.request.user.employee
        self.object.save()

        files = self.request.FILES.getlist('files')

        if files:
            NoticeFile.objects.filter(notice=self.object).delete()
            for file in files:
                NoticeFile.objects.create(
                    notice=self.object,
                    file=file
                )

        messages.success(self.request, f'Notice updated successfully')
        return redirect(self.get_success_url())

    def get_context_data(self, **kwargs) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['breadcrumbs'] = [
            {'name': 'Notices', 'url': reverse_lazy(
                'noticeboard:notice_list')},
            {'name': 'Update', 'url': '#'},
        ]
        return context


class NoticeDeleteView(CompanyAdminRequiredMixin, generic.DeleteView):
    model = Notice
    template_name = 'organization/delete_confirmation.html'
    success_url = reverse_lazy('noticeboard:dashboard')
    fallback_url = reverse_lazy('noticeboard:dashboard')

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['cancel_redirect_url'] = self.get_success_url()
        context['breadcrumbs'] = [
            {'name': 'Notices', 'url': reverse_lazy(
                'noticeboard:notice_list')},
            {'name': 'Delete', 'url': '#'},
        ]
        return context
