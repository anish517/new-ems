from django import forms

from organization.models import Employee
from . models import Contract


class ContractForm(forms.ModelForm):
    class Meta:
        model = Contract
        fields = ['employee', 'start_date', 'end_date', 'responsibilites']
        widgets = {
            'employee': forms.Select(attrs={'class': 'select2'})
        }

    def __init__(self, *args, **kwargs):
        user = kwargs.pop('user')
        super(ContractForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            existing_classes = field.widget.attrs.get('class', '')
            field.widget.attrs['class'] = f'{existing_classes} form-control'.strip()

        if user and user.employee.organization:
            self.fields['employee'].queryset = Employee.objects.filter(
                post__department__organization=user.employee.organization)
        else:
            self.fields['employee'].queryset = Employee.objects.none()
