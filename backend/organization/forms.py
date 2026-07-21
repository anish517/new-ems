from django import forms
from django.contrib.auth import get_user_model

from .models import Organization, Department, Employee, Post, EmployeeDocument, OtherDocument, OrganizationFolder, OrganizationFile

User = get_user_model()


class OrganizationForm(forms.ModelForm):
    class Meta:
        model = Organization
        fields = ['name', 'website', 'type_of_organization', 'contact_person',
                  'contact_number', 'opening_time', 'closing_time']
        widgets = {
            'opening_time': forms.TimeInput(attrs={'type': 'time', 'placeholder': "hrs:mins"}),
            'closing_time': forms.TimeInput(attrs={'type': 'time', 'placeholder': "hrs:mins"}),
        }

    def __init__(self, *args, **kwargs):
        super(OrganizationForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            field.widget.attrs['class'] = 'form-control'


class DepartmentForm(forms.ModelForm):
    class Meta:
        model = Department
        fields = '__all__'
        exclude = ['department_slug', 'organization']

    def __init__(self, *args, **kwargs):
        user = kwargs.pop('user', None)  # Pop the user from the kwargs
        organization = user.employee.organization
        super(DepartmentForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            field.widget.attrs['class'] = 'form-control'

        if user and user.employee.organization:  # Ensure the user and user's organization are not None
            self.fields['parent_department'].queryset = user.employee.organization.departments
            employess_list = user.employee.organization.employees.values_list(
                'id', flat=True)
        else:
            self.fields['parent_department'].queryset = Department.objects.none()


class EmployeeForm(forms.ModelForm):
    class Meta:
        model = Employee
        fields = '__all__'
        exclude = ['user', 'status']
        widgets = {
            'date_of_birth': forms.TextInput(attrs={'type': 'text', 'class': 'nepali-date'}),
            'hired_date': forms.TextInput(attrs={'type': 'text', 'class': 'nepali-date'}),
            'contract_end_date': forms.TextInput(attrs={'type': 'text', 'class': 'nepali-date'}),
        }

    def __init__(self, *args, **kwargs):
        super(EmployeeForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            existing_classes = field.widget.attrs.get('class', '')
            field.widget.attrs['class'] = f'{existing_classes} form-control'.strip()


class EmployeeDocumentForm(forms.ModelForm):
    class Meta:
        model = EmployeeDocument
        fields = '__all__'
        exclude = ['employee']

    def __init__(self, *args, **kwargs):
        super(EmployeeDocumentForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            field.widget = forms.FileInput()
            field.widget.attrs['class'] = 'form-control'


class PostForm(forms.ModelForm):
    class Meta:
        model = Post
        fields = '__all__'

    def __init__(self, *args, **kwargs):
        user = kwargs.pop('user', None)
        super(PostForm, self).__init__(*args, **kwargs)
        self.fields['department'].queryset = user.employee.organization.departments
        for field_name, field in self.fields.items():

            field.widget.attrs['class'] = 'form-control'


class OrganizationFolderForm(forms.ModelForm):
    class Meta:
        model = OrganizationFolder
        fields = '__all__'
        exclude = ['organization', 'parent']

    def __init__(self, *args, **kwargs):
        super(OrganizationFolderForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            field.widget.attrs['class'] = 'form-control'


class OrganizationFileForm(forms.ModelForm):
    class Meta:
        model = OrganizationFile
        fields = '__all__'
        exclude = ['organization', 'parent', 'folder']

    def __init__(self, *args, **kwargs):
        super(OrganizationFileForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            field.widget.attrs['class'] = 'form-control'
