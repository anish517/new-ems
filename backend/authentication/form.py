from django import forms
from django.contrib.auth.forms import UserCreationForm, UserChangeForm
from .models import Account


class AccountCreationForm(UserCreationForm):
    class Meta:
        model = Account
        fields = ['first_name', 'last_name',
                  'email', 'profile_picture', 'password1', 'password2']

    def clean_email(self):
        email = self.cleaned_data['email'].lower()
        if Account.objects.filter(email=email).exists():
            raise forms.ValidationError('Email address already in use.')
        return email

    def save(self, commit=True):
        user = super().save(commit=False)
        user.email = self.cleaned_data['email'].lower()
        if commit:
            user.save()
        return user

    def __init__(self, *args, **kwargs):
        super(AccountCreationForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            field.widget.attrs['class'] = 'form-control'


class AccountUpdateForm(UserChangeForm):
    class Meta:
        model = Account
        fields = ['first_name', 'last_name', 'email', 'profile_picture']

    def __init__(self, *args, **kwargs):
        super(AccountUpdateForm, self).__init__(*args, **kwargs)
        for field_name, field in self.fields.items():
            field.widget.attrs['class'] = 'form-control'
        self.fields['profile_picture'].widget.attrs['class'] = 'form-control'
