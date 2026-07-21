from django import forms
from django_ckeditor_5.widgets import CKEditor5Widget

from organization.models import Employee
from .models import Complain, ComplainCategory, ComplainReply


class ComplainForm(forms.ModelForm):
    class Meta:
        model = Complain
        fields = ['title', 'category', 'visibility', 'description']
        widgets = {
            'title': forms.TextInput(attrs={'class': 'form-control', 'required': True}),
            'visibility': forms.Select(attrs={'class': 'form-control', 'required': True}),
            'category': forms.Select(attrs={'class': 'default-select form-control wide'}),
        }

    def __init__(self, *args, **kwargs):
        user = kwargs.pop('user')
        employee: Employee = user.employee
        super(ComplainForm, self).__init__(*args, **kwargs)

        self.fields['category'].queryset = ComplainCategory.objects.filter(
            organization=employee.organization)


class ComplainReplyForm(forms.ModelForm):
    class Meta:
        model = ComplainReply
        fields = ['content']
