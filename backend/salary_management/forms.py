from django import forms
from django_ckeditor_5.widgets import CKEditor5Widget

from .models import SalaryTransaction, Salary, SalaryTransactionReview


class SalaryForm(forms.ModelForm):
    class Meta:
        model = Salary
        fields = ['employee', 'basic_salary', 'ssf', 'tds', 'epf',
                  'citizen_investment_trust', 'insurance']

    def __init__(self, *args, **kwargs):
        user = kwargs.pop('user')
        super(SalaryForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            field.widget.attrs['class'] = 'form-control'

        if user and user.employee.organization:
            self.fields['employee'].queryset = user.employee.organization.employees


class SalaryTransactionForm(forms.ModelForm):
    net_salary = forms.CharField(required=False, disabled=True)

    class Meta:
        model = SalaryTransaction
        fields = ['salary', 'fiscal_year', 'date',
                  'net_salary', 'content']
        exclude = ['organization']
        widgets = {
            'date': forms.TextInput(attrs={'type': 'text', 'class': 'nepali-date'}),
            'total_salary': forms.TextInput(),
        }

    def __init__(self, *args, **kwargs):
        user = kwargs.pop('user', None)
        super(SalaryTransactionForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            existing_classes = field.widget.attrs.get('class', '')
            field.widget.attrs['class'] = f'{existing_classes} form-control'.strip()
        if user and user.employee.organization:
            self.fields['salary'].queryset = Salary.objects.filter(
                organization=user.employee.organization)
        else:
            self.fields['employee'].queryset = Salary.objects.none()


class SalaryTransactionReviewForm(forms.ModelForm):
    class Meta:
        model = SalaryTransactionReview
        fields = [
            'content'
        ]
        widgets = {
            'content': CKEditor5Widget(
                attrs={'class': 'django_ckeditor_5',
                       'status': {'width': '100%'}},
                config_name='extends'
            )
        }
