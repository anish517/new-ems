from typing import Any
from django.forms import BaseModelForm
from django.http import HttpResponse
from django.urls import reverse_lazy
from django.shortcuts import render, redirect
from django.contrib import messages
from django.views.generic import TemplateView, CreateView, UpdateView, DetailView
from .models import Category, Event
from .forms import EventForm

# Create your views here.


class Calendar(TemplateView):
    template_name = 'calendar_app/calendar_bs.html'

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['event_types'] = Category.objects.all()
        return context


class EventAddView(CreateView):
    model = Event
    template_name = 'calendar_app/event_add.html'
    form_class = EventForm
    success_url = reverse_lazy('calendar_app:calendar')

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object = form.save()
        self.object.organization = self.request.user.employee.organization
        self.object.save()
        messages.success(self.request, 'Event added successfully')
        return redirect(self.get_success_url())

    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['event_types'] = Category.objects.all()
        return context


class EventDetailView(DetailView):
    model = Event
    template_name = 'calendar_app/event_detail.html'


class EventUpdateView(UpdateView):
    model = Event
    template_name = 'calendar_app/event_update.html'
    form_class = EventForm
    success_url = reverse_lazy('calendar_app:calendar')

    def form_valid(self, form: BaseModelForm) -> HttpResponse:
        self.object = form.save()
        messages.success(self.request, 'Event updated successfully')
        return redirect(self.get_success_url())
