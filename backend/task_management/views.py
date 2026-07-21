from django.db.models.query import QuerySet
import nepali_datetime
from typing import Any
from django.forms import BaseModelForm
from django.http import HttpResponse
from django.shortcuts import render, redirect
from django.views import generic
from django.urls import reverse_lazy
from django.contrib import messages

from organization.models import Employee
from organization.utils import get_analysis_report

from task_management.filters import TaskFilter
from task_management.forms import ProjectForm, TaskForm
from task_management.utils import get_employees_list_with_task

from authorization.mixins import CompanyAdminRequiredMixin

from .models import Project, Task
# Create your views here.


class AdminDashboard(CompanyAdminRequiredMixin, generic.TemplateView):
    template_name = 'task_management/admin_dashboard.html'
    fallback_url = reverse_lazy('task_management:employee_dashboard')

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        employee: Employee = self.request.user.employee
        context = super().get_context_data(**kwargs)
        context['employee'] = employee
        context['projects'] = Project.objects.filter(
            organization=employee.organization)
        tasks = Task.objects.filter(
            project__organization=employee.organization)
        context['pending_tasks'] = tasks.filter(status='to-do')
        context['in_progress_tasks'] = tasks.filter(status='in-progress')
        context['completed_tasks'] = tasks.filter(status='done')
        context['employees'] = get_employees_list_with_task(
            organization=employee.organization)
        context['breadcrumbs'] = [
            {'name': 'Task management', 'url': ''}
        ]
        return context


class EmployeeDashboard(generic.TemplateView):
    template_name = 'task_management/employee_dashboard.html'

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
        employee_id = self.request.GET.get(
            'employee', self.request.user.employee.id)
        employee = Employee.objects.get(id=employee_id)
        context = super().get_context_data(**kwargs)
        context['organization'] = employee.organization
        context['employee'] = employee
        context['projects'] = 2
        tasks = Task.objects.filter(
            assigned_to=employee)
        context['tasks'] = tasks
        context['pending_tasks'] = tasks.filter(
            status='to-do').order_by('planned_end_date')
        context['in_progress_tasks'] = tasks.filter(
            status='in-progress').order_by('planned_end_date')
        context['completed_tasks'] = tasks.filter(status='done')
        context['employees'] = get_employees_list_with_task(
            organization=employee.organization)
        context['analysis_report'] = get_analysis_report(employee=employee)
        context['breadcrumbs'] = [
            {'name': 'Task management', 'url': ''}
        ]
        return context


class ProjectCreateView(CompanyAdminRequiredMixin, generic.CreateView):
    model = Project
    form_class = ProjectForm
    template_name = 'task_management/project_create.html'
    success_url = reverse_lazy('task_management:admin_dashboard')
    fallback_url = reverse_lazy('task_management:employee_dashboard')

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['breadcrumbs'] = [
            {'name': 'Task management', 'url': self.success_url},
            {'name': 'Project', 'url': ''},
            {'name': 'Add', 'url': reverse_lazy(
                'task_management:project_create')}
        ]
        return context

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object: Project = form.save(commit=False)
        employee: Employee = self.request.user.employee
        self.object.organization = employee.organization
        self.object.created_by = employee
        self.object.created_at = nepali_datetime.date.today()
        self.object.updated_at = nepali_datetime.date.today()
        self.object.save()
        messages.success(self.request, 'New project was created.')
        return redirect(self.success_url)


class ProjectDetailView(CompanyAdminRequiredMixin, generic.DetailView):
    model = Project
    context_object_name = 'project'
    fallback_url = reverse_lazy('task_management:employee_dashboard')

    def get_queryset(self) -> QuerySet[Project]:
        employee: Employee = self.request.user.employee
        return Project.objects.filter(organization=employee.organization)

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        employee: Employee = self.request.user.employee
        context = super().get_context_data(**kwargs)
        tasks = Task.objects.filter(project=self.get_object())
        context['tasks'] = tasks
        context['completed_tasks'] = tasks.filter(status='done')
        context['in_progress_tasks'] = tasks.filter(status='in-progress')
        context['pending_tasks'] = tasks.filter(status='to-do')
        context['team_members'] = self.get_object().get_team_members()
        if employee.is_company_admin():
            context['breadcrumbs'] = [
                {'name': 'Task management', 'url': reverse_lazy(
                    'task_management:admin_dashboard')},
                {'name': 'Project', 'url': ''},
                {'name': 'Detail', 'url': reverse_lazy(
                    'task_management:project_detail', kwargs={'pk': self.get_object().pk})}
            ]
        else:
            context['breadcrumbs'] = [
                {'name': 'Task management', 'url': reverse_lazy(
                    'task_management:employee_dashboard')},
                {'name': 'Project', 'url': ''},
                {'name': 'Detail', 'url': reverse_lazy(
                    'task_management:project_detail', kwargs={'pk': self.get_object().pk})}
            ]
        return context


def task_list(request):
    employee: Employee = request.user.employee
    if employee.is_company_admin():
        queryset = Task.objects.filter(
            created_by__post__department__organization=employee.organization)
    else:
        queryset = Task.objects.filter(assigned_to=employee)

    task_filter = TaskFilter(
        request.GET, queryset=queryset, user=request.user
    )
    filtered_tasks = task_filter.qs
    context = {
        "tasks":  filtered_tasks,
        'filter': task_filter,
    }
    if employee.is_company_admin():
        context['breadcrumbs'] = [
            {'name': 'Task management', 'url': reverse_lazy(
                'task_management:admin_dashboard')},
            {'name': 'Tasks', 'url': reverse_lazy(
                'task_management:task_list')},
        ]
    else:
        context['breadcrumbs'] = [
            {'name': 'Task management', 'url': reverse_lazy(
                'task_management:employee_dashboard')},
            {'name': 'Tasks', 'url': reverse_lazy(
                'task_management:task_list')},
        ]
    return render(request, 'task_management/task_list.html', context=context)


class TaskCreate(CompanyAdminRequiredMixin, generic.CreateView):
    model = Task
    form_class = TaskForm
    template_name = 'task_management/task_create.html'
    fallback_url = reverse_lazy('task_management:employee_dashboard')

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['breadcrumbs'] = [
            {'name': 'Task management', 'url': reverse_lazy(
                'task_management:admin_dashboard')},
            {'name': 'Tasks', 'url': reverse_lazy(
                'task_management:task_list')},
            {'name': 'Add', 'url': reverse_lazy('task_management:task_create')}
        ]
        return context

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object = form.save(commit=False)
        self.object.created_by = self.request.user.employee
        self.object.updated_by = self.request.user.employee
        self.object.created_at = nepali_datetime.date.today()
        self.object.updated_at = nepali_datetime.date.today()
        self.object.save()
        messages.success(self.request, 'New task created succesfully.')
        return redirect(self.get_success_url())

    def get_success_url(self) -> str:
        return reverse_lazy('task_management:task_details', kwargs={'pk': self.object.pk})


class TaskDetail(generic.DetailView):
    model = Task
    template_name = 'task_management/task_detail.html'
    context_object_name = 'task'

    def dispatch(self, request, *args, **kwargs):
        employee_id = self.request.GET.get(
            'employee', self.request.user.employee.id)

        if self.request.user.employee == self.get_object().assigned_to or self.request.user.employee.is_company_admin():
            return super().dispatch(request, *args, **kwargs)
        else:
            messages.error(request, "Unauthorized")
            return redirect('authentication:dashboard')

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        employee: Employee = self.request.user.employee
        context = super().get_context_data(**kwargs)
        if employee.is_company_admin():
            context['breadcrumbs'] = [
                {'name': 'Task management', 'url': reverse_lazy(
                    'task_management:admin_dashboard')},
                {'name': 'Tasks', 'url': reverse_lazy(
                    'task_management:task_list')},
                {'name': 'Detail', 'url': reverse_lazy(
                    'task_management:task_details', kwargs={'pk': self.get_object().pk})}
            ]
        else:
            context['breadcrumbs'] = [
                {'name': 'Task management', 'url': reverse_lazy(
                    'task_management:employee_dashboard')},
                {'name': 'Tasks', 'url': reverse_lazy(
                    'task_management:task_list')},
                {'name': 'Detail', 'url': reverse_lazy(
                    'task_management:task_details', kwargs={'pk': self.get_object().pk})}
            ]
        return context


class TaskUpdate(CompanyAdminRequiredMixin, generic.UpdateView):
    model = Task
    form_class = TaskForm
    template_name = 'task_management/task_edit.html'
    fallback_url = reverse_lazy('task_management:employee_dashboard')

    def get_success_url(self) -> str:
        return reverse_lazy('task_management:task_details', kwargs={'pk': self.get_object().pk})

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['breadcrumbs'] = [
            {'name': 'Task management', 'url': reverse_lazy(
                'task_management:admin_dashboard')},
            {'name': 'Task details', 'url': reverse_lazy(
                'task_management:task_details', kwargs={'pk': self.get_object().pk})},
            {'name': 'Task edit', 'url': ''}
        ]
        return context

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object = form.save(commit=False)
        self.object.updated_by = self.request.user.employee
        self.object.updated_at = nepali_datetime.date.today()
        self.object.save()
        messages.success(self.request, 'Task updated succesfully')
        return redirect(self.get_success_url())
