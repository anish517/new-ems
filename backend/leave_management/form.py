from django import forms
from .models import LeaveRequest, LeaveType


class LeaveTypeForm(forms.ModelForm):
    class Meta:
        model = LeaveType
        fields = '__all__'
        exclude = ['organization', 'slug']
        widget = {
            'is_paid': forms.CheckboxInput(attrs={})
        }

    def __init__(self, *args, **kwargs):
        super(LeaveTypeForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            field.widget.attrs['class'] = 'form-control'


class LeaveRequestForm(forms.ModelForm):
    class Meta:
        model = LeaveRequest
        fields = '__all__'
        exclude = ['organization', 'employee', 'is_approved', 'is_paid',
                   'remarks', 'created_at', 'is_reviewed']
        widgets = {
            'from_date': forms.TextInput(attrs={'type': 'text', 'class': 'nepali-date'}),
            'till_date': forms.TextInput(attrs={'type': 'text', 'class': 'nepali-date'}),
        }

    def __init__(self, *args, **kwargs):
        user = kwargs.pop('user')
        super(LeaveRequestForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            existing_classes = field.widget.attrs.get('class', '')
            field.widget.attrs['class'] = f'{existing_classes} form-control'.strip()

        if user and user.employee.organization:
            self.fields['type'].queryset = LeaveType.objects.filter(
                organization=user.employee.organization)
        else:
            self.fields['type'].queryset = LeaveType.objects.none()
