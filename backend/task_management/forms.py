from django import forms

from .models import Project, Task


class TaskForm(forms.ModelForm):

    class Meta:
        model = Task
        fields = ['project', 'assigned_to', 'title',
                  'status', 'priority', 'planned_start_date', 'planned_end_date', 'description']
        widgets = {
            'project': forms.Select(attrs={'class': 'form-control select2', 'required': True}),
            'assigned_to': forms.Select(attrs={'class': 'form-control select2', 'required': True}),
            'title': forms.TextInput(attrs={'class': 'form-control', 'required': True}),
            'status': forms.Select(attrs={'class': 'form-control', 'required': True}),
            'priority': forms.Select(attrs={'class': 'form-control', 'required': True}),
            'planned_start_date': forms.TextInput(attrs={'class': 'form-control nepali-date', 'required': True}),
            'planned_end_date': forms.TextInput(attrs={'class': 'form-control nepali-date', 'required': True}),

        }


class ProjectForm(forms.ModelForm):
    class Meta:
        model = Project
        fields = ['title', 'abbreviation', 'description']
        widgets = {
            'title': forms.TextInput(attrs={'class': 'form-control', 'placeholder': 'E.g. Project Foo Bar'}),
            'abbreviation': forms.TextInput(attrs={'class': 'form-control', 'placeholder': "Eg. PFB"})
        }
