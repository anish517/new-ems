from typing import Any
from django.db.models.query import QuerySet
from django.urls import reverse
from django.views.generic import ListView
from . models import ActivityLog

# Create your views here.

class LogListView(ListView):
    model = ActivityLog
    template_name = 'logs/log_list.html'
    context_object_name = 'log_entries'

    def get_queryset(self) -> QuerySet[ActivityLog]:
        return ActivityLog.objects.all().order_by('-timestamp')
    
    def get_context_data(self, **kwargs: Any) -> dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context['breadcrumbs'] = [
            {'name': 'Activity logs', 'url': reverse('logs:list')},
        ]
        return context