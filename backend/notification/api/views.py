from rest_framework import generics, serializers
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated

from notification.models import Notification, DeviceToken
from .serializers import NotificationSerializer


class NotificationListApiView(generics.ListAPIView):
    """Returns unread notifications for the current user (used for badge count)."""
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return self.request.user.notifications.all().order_by('-created_at')


class MarkAllNotificationsAsReadView(APIView):
    """Marks all notifications as read for the current user."""
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):
        request.user.notifications.filter(is_read=False).update(is_read=True)
        return Response({'status': 'all notifications marked as read'}, status=status.HTTP_200_OK)


class RegisterDeviceTokenView(APIView):
    """
    Flutter calls this on startup/login to register the FCM device token.
    POST /api/notification/device-token/
    Body: { "token": "<FCM_token>" }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):
        token = request.data.get('token')
        if not token:
            return Response({'error': 'token is required'}, status=status.HTTP_400_BAD_REQUEST)
        # Use update_or_create based on token to handle cases where 
        # a different user logs into the same device
        DeviceToken.objects.update_or_create(
            token=token,
            defaults={'user': request.user}
        )
        return Response({'status': 'token registered'}, status=status.HTTP_201_CREATED)


class NotificationRetrieveUpdateDestroyAPIView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return self.request.user.notifications.all()
