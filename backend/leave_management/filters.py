import django_filters
from django import forms
from .models import LeaveRequest


class LeaveRequestFilter(django_filters.FilterSet):
    is_approved = django_filters.BooleanFilter(
        field_name='is_approved', label='Is Approved',
        widget=forms.Select(choices=[('', 'Any'), (True, 'Approved'), (False, 'Declined')], attrs={
                            'type': 'text', 'class': 'form-control'})
    )
    is_reviewed = django_filters.BooleanFilter(
        field_name='is_reviewed', label='Status',
        widget=forms.Select(choices=[('', 'Any'), (True, 'Reviewed'), (False, 'Pending')], attrs={
                            'class': 'form-control'})
    )
    is_paid = django_filters.BooleanFilter(
        field_name='is_paid', label='Remuneration',
        widget=forms.Select(choices=[('', 'Any'), (True, 'Paid'), (False, 'Unpaid')], attrs={
                            'class': 'form-control'})
    )

    class Meta:
        model = LeaveRequest
        fields = ['is_reviewed', 'is_approved', 'is_paid',]
