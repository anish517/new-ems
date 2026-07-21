import django_filters
from django import forms

from organization.models import Organization, Employee
from .models import Attendance


class AttendanceFilter(django_filters.FilterSet):
    employee = django_filters.ModelChoiceFilter(
        queryset=Employee.objects.none(),
        widget=forms.Select(attrs={'class': 'form-control select2'}),
        label='Employee'
    )

    class Meta:
        model = Attendance
        fields = ['employee']

    def __init__(self, *args, **kwargs):
        user = kwargs.pop('user')
        employee: Employee = user.employee
        organization: Organization = employee.organization
        super().__init__(*args, **kwargs)
        self.filters['employee'].queryset = organization.employees
