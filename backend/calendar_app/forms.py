from django import forms

from .models import Event


class EventForm(forms.ModelForm):
    class Meta:
        model = Event
        fields = ['category', 'title', 'start', 'end',
                  'location', 'is_holiday', 'description']
        widgets = {
            'start': forms.TextInput(attrs={'type': 'text', 'class': 'nepali-date'}),
            'end': forms.TextInput(attrs={'type': 'text', 'class': 'nepali-date'}),
            'description': forms.Textarea(attrs={'rows': 3, },)
        }

    def __init__(self, *args, **kwargs):
        super(EventForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            existing_classes = field.widget.attrs.get('class', '')
            field.widget.attrs['class'] = f'{existing_classes} form-control'.strip()
