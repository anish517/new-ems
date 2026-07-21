from django import forms
from .models import FiscalYear

class FiscalYearForm(forms.ModelForm):
    class Meta:
        model = FiscalYear
        fields = ['title']

    def __init__(self, *args, **kwargs):
        super(FiscalYearForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            field.widget.attrs['class'] = 'form-control'