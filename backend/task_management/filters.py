import django_filters

from django import forms

from organization.models import Employee, Organization
from .models import Task, Project


class TaskFilter(django_filters.FilterSet):
    project = django_filters.ModelChoiceFilter(
        queryset=Task.objects.none(),
        widget=forms.Select(attrs={'class': 'form-control select2'}),
        label='Project',
    )
    assigned_to = django_filters.ModelChoiceFilter(
        queryset=Employee.objects.none(),
        widget=forms.Select(attrs={'class': 'form-control select2'}),
        label='Assigned To',
    )
    status = django_filters.ChoiceFilter(
        choices=Task.STATUS_CHOICES,  # Assuming you have status choices in your model
        widget=forms.Select(attrs={'class': 'form-control'}),
        label='Status',
    )
    priority = django_filters.ChoiceFilter(
        choices=Task.PRIORITY_CHOICES,  # Assuming you have priority choices in your model
        widget=forms.Select(attrs={'class': 'form-control'}),
        label='Priority',
    )

    class Meta:
        model = Task
        fields = ['project', 'assigned_to', 'status', 'priority']

    def __init__(self, *args, **kwargs):
        user = kwargs.pop('user')
        employee: Employee = user.employee
        organization: Organization = employee.organization
        super().__init__(*args, **kwargs)
        self.filters['project'].queryset = Project.objects.filter(
            organization=organization)
        self.filters['assigned_to'].queryset = organization.employees
