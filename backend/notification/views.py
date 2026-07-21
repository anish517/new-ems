from django.views import generic
from django.urls import reverse_lazy

from notification.models import Notification


class NotificationListView(generic.ListView):
    model = Notification
    template_name = 'notification/notification_list.html'
    context_object_name = 'notifications'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['breadcrumbs'] = [
            {'name': 'Notifications', 'url': reverse_lazy(
                'notification:notification_list')}
        ]
        return context

    def get_queryset(self):
        return self.request.user.notifications.all().order_by('-created_at')
