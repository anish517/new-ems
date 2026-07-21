import time
from rest_framework import generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator


from notification.models import Notification

from .serializers import NotificationSerializer


class NotificationListApiView(generics.ListAPIView):
    serializer_class = NotificationSerializer

    def get_queryset(self):
        return self.request.user.notifications.filter(is_read=False).order_by('-created_at')


@method_decorator(csrf_exempt, name='dispatch')
class MarkAllNotificationsAsReadView(APIView):
    def get(self, request, *args, **kwargs):
        if not request.user.is_authenticated:
            return Response({'error': 'Authentication required'}, status=status.HTTP_401_UNAUTHORIZED)

        notifications = Notification.objects.filter(users=request.user)
        for notification in notifications:
            notification.users.remove(request.user)

        return Response({'status': 'all notifications marked as read'}, status=status.HTTP_200_OK)


class NotificationRetrieveUpdateDestroyAPIView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = NotificationSerializer
    queryset = Notification.objects.all()
    permission_classes = [IsAuthenticated]

    def dispatch(self, request, *args, **kwargs):
        return super().dispatch(request, *args, **kwargs)
