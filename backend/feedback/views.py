from typing import Any
from django.db.models.query import QuerySet
from django.forms import BaseModelForm
from django.http import HttpResponse
from django.shortcuts import render, redirect
from django.urls import reverse_lazy
from django.contrib import messages
from django.views import generic

from authorization.mixins import CompanyAdminRequiredMixin, OwnerAndAdminOnlyMixin, OwnerOnlyMixin
from organization.models import Employee
from .models import Complain, ComplainReply
from .forms import ComplainForm, ComplainReplyForm
# Create your views here.


class AdminDashboard(CompanyAdminRequiredMixin, generic.TemplateView):
    template_name = 'feedback/admin_dashboard.html'
    fallback_url = reverse_lazy('feedback:employee_dashboard')

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        employee: Employee = self.request.user.employee
        context = super().get_context_data(**kwargs)
        context['complains'] = Complain.objects.filter(
            organization=employee.organization).order_by('-created_at')
        context['pending_complains'] = context['complains'].filter(
            status='pending')
        context['reviewed_complains'] = context['complains'].filter(
            status='reviewed')
        context['breadcrumbs'] = [
            {'name': 'Feedback', 'url': reverse_lazy(
                'feedback:admin_dashboard')},
        ]
        return context


class EmployeeDashboard(generic.TemplateView):
    template_name = 'feedback/employee_dashboard.html'

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        employee = self.request.user.employee
        context = super().get_context_data(**kwargs)
        context['complains'] = Complain.objects.filter(owner=employee)
        context['pending_complains'] = context['complains'].filter(
            status='pending')
        context['reviewed_complains'] = context['complains'].filter(
            status='reviewed')
        context['breadcrumbs'] = [
            {'name': 'Feedback', 'url': reverse_lazy(
                'feedback:employee_dashboard')},
        ]
        return context


class FeedbackCategoryListView(generic.ListView):
    pass


def complain_list_view(request):
    employee: Employee = request.user.employee
    if employee.is_company_admin():
        complains = Complain.objects.filter(organization=employee.organization)
    else:
        complains = Complain.objects.filter(owner=employee)

    context = {
        'complains': complains
    }

    if employee.is_company_admin():
        context['breadcrumbs'] = [
            {'name': 'Feedback', 'url': reverse_lazy(
                'feedback:admin_dashboard')},
            {'name': 'Complains', 'url': reverse_lazy(
                'feedback:complain_list')},
        ]
    else:
        context['breadcrumbs'] = [
            {'name': 'Feedback', 'url': reverse_lazy(
                'feedback:employee_dashboard')},
            {'name': 'Complains', 'url': reverse_lazy(
                'feedback:complain_list')},
        ]
    return render(request, 'feedback/complain_list.html', context=context)


class ComplainCreateView(generic.CreateView):
    model = Complain
    template_name = 'feedback/complain_create.html'
    form_class = ComplainForm

    def get_success_url(self) -> str:
        return reverse_lazy('feedback:employee_dashboard')

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object = form.save(commit=False)
        self.object.organization = self.request.user.employee.organization
        self.object.owner = self.request.user.employee
        self.object.save()
        messages.success(
            self.request, "Your complain was submitted successfully.")
        return redirect(self.get_success_url())

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        employee: Employee = self.request.user.employee
        context = super().get_context_data(**kwargs)
        if employee.is_company_admin():
            context['breadcrumbs'] = [
                {'name': 'Feedback', 'url': reverse_lazy(
                    'feedback:admin_dashboard')},
                {'name': 'Complains', 'url': reverse_lazy(
                    'feedback:complain_list')},
                {'name': 'Add', 'url': reverse_lazy('feedback:complain_add')}
            ]
        else:
            context['breadcrumbs'] = [
                {'name': 'Feedback', 'url': reverse_lazy(
                    'feedback:employee_dashboard')},
                {'name': 'Complains', 'url': reverse_lazy(
                    'feedback:complain_list')},
                {'name': 'Add', 'url': reverse_lazy('feedback:complain_add')},
            ]
        return context

    def get_form_kwargs(self):
        kwargs = super().get_form_kwargs()
        kwargs["user"] = self.request.user
        return kwargs


class ComplainDetailView(OwnerAndAdminOnlyMixin, generic.DetailView):
    model = Complain
    template_name = 'feedback/complain_detail.html'
    context_object_name = 'complain'
    fallback_url = reverse_lazy('feedback:employee_dashboard')

    def get_queryset(self) -> QuerySet[Complain]:
        employee: Employee = self.request.user.employee
        qs = Complain.objects.filter(organization=employee.organization)
        return qs

    def get_context_data(self, **kwargs) -> dict[str, Any]:
        employee: Employee = self.request.user.employee

        context = super().get_context_data(**kwargs)
        context['reply'] = ComplainReply.objects.filter(
            complain=self.get_object()).first()

        if context['reply']:
            context['reply_form'] = ComplainReplyForm(
                instance=context['reply'])
        else:
            context['reply_form'] = ComplainReplyForm()

        if employee.is_company_admin():
            obj = self.get_object()
            obj.status = 'reviewed'
            obj.save()
            context['breadcrumbs'] = [
                {'name': 'Feedback', 'url': reverse_lazy(
                    'feedback:admin_dashboard')},
                {'name': 'Complains', 'url': reverse_lazy(
                    'feedback:complain_list')},
                {'name': 'Detail', 'url': ''}
            ]
        else:
            context['breadcrumbs'] = [
                {'name': 'Feedback', 'url': reverse_lazy(
                    'feedback:employee_dashboard')},
                {'name': 'Complains', 'url': reverse_lazy(
                    'feedback:complain_list')},
                {'name': 'Detail', 'url': ''}
            ]

        return context


class ComplainUpdateView(OwnerOnlyMixin, generic.UpdateView):
    model = Complain
    template_name = 'feedback/complain_update.html'
    form_class = ComplainForm

    def get_success_url(self) -> str:
        return reverse_lazy('feedback:complain_detail', kwargs={'pk': self.get_object().pk})

    def get_queryset(self) -> QuerySet[Any]:
        employee: Employee = self.request.user.employee
        qs = Complain.objects.filter(organization=employee.organization)
        return qs

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        employee: Employee = self.request.user.employee
        context = super().get_context_data(**kwargs)

        if employee.is_company_admin():
            context['breadcrumbs'] = [
                {'name': 'Feedback', 'url': reverse_lazy(
                    'feedback:admin_dashboard')},
                {'name': 'Detail', 'url': reverse_lazy(
                    'feedback:complain_detail', kwargs={'pk': self.get_object().pk})},
                {'name': 'Edit', 'url': ''}
            ]
        else:
            context['breadcrumbs'] = [
                {'name': 'Feedback', 'url': reverse_lazy(
                    'feedback:employee_dashboard')},
                {'name': 'Detail', 'url': reverse_lazy(
                    'feedback:complain_detail', kwargs={'pk': self.get_object().pk})},
                {'name': 'Edit', 'url': ''}
            ]
        return context

    def get_form_kwargs(self):
        kwargs = super().get_form_kwargs()
        kwargs["user"] = self.request.user
        return kwargs


def complain_delete_view(request, pk):
    complain = Complain.objects.get(pk=pk)
    if request.method == 'POST':
        if request.user.employee == complain.employee:
            complain.delete()
            messages.success(request, 'Complain deleted successfully.')

        else:
            messages.error(request, 'Unauthorized')
        return redirect('feedback:admin_dashbord')

    context = {
        'cancel_redirect_url': request.META.get('HTTP_REFERER')
    }

    return render(request, 'feedback/delete_confirmation.html', context=context)


def create_complain_reply(request):
    if request.method == 'POST':
        employee: Employee = request.user.employee
        complain = Complain.objects.get(id=request.POST.get('complain'))
        reply, created = ComplainReply.objects.get_or_create(
            organization=employee.organization,
            employee=employee,
            complain=complain
        )
        form = ComplainReplyForm(data=request.POST, instance=reply)
        if employee.is_company_admin():
            if form.is_valid():
                reply = form.save()
                messages.success(request, 'Reply posted successfully')
            else:
                messages.error('Form invalid')
        else:
            messages.error(request, 'Unauthorized')

        return redirect(reverse_lazy('feedback:complain_detail', kwargs={'pk': complain.pk}))

    else:
        return HttpResponse('Method not allowed')
