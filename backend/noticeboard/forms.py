from django import forms
from django_ckeditor_5.widgets import CKEditor5Widget

from .models import Notice
from organization.models import Employee

class NoticeForm(forms.ModelForm):
    class Meta:
        model = Notice
        fields = [
            'date', 'title', 'description'
        ]
    
    def __init__(self, *args, **kwargs):
        super(NoticeForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            if field_name != 'description':
                existing_classes = field.widget.attrs.get('class', '')
                field.widget.attrs['class'] = f'{existing_classes} form-control'.strip()