from rest_framework import viewsets, generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.contrib.auth.tokens import default_token_generator
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode
from django.utils.encoding import force_bytes, force_str
from django.core.mail import send_mail
from django.conf import settings
from django.utils import timezone
import uuid

from authentication.models import Account
from .serializers import AccountSerializer, ChangePasswordSerializer, MeSerializer


class AccountViewSet(viewsets.ModelViewSet):
    queryset = Account.objects.all()
    serializer_class = AccountSerializer
    permission_classes = [IsAuthenticated]


class MeView(APIView):
    """Returns the currently authenticated user's profile with role info."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = MeSerializer(request.user, context={'request': request})
        return Response(serializer.data)

    def patch(self, request):
        serializer = AccountSerializer(request.user, data=request.data,
                                       partial=True, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return Response(MeSerializer(request.user, context={'request': request}).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ChangePasswordView(generics.GenericAPIView):
    serializer_class = ChangePasswordSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        if serializer.is_valid():
            request.user.set_password(serializer.validated_data['new_password'])
            request.user.save()
            return Response({'message': 'Password changed successfully.'})
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


def _get_display_name(user):
    """
    Returns the best available display name for a user, without relying
    on Django's default AbstractUser.get_full_name(), which our custom
    Account model does not implement.
    """
    full_name = getattr(user, 'full_name', None)
    if full_name:
        return full_name

    first = getattr(user, 'first_name', '') or ''
    last = getattr(user, 'last_name', '') or ''
    combined = f'{first} {last}'.strip()
    if combined:
        return combined

    return user.email


class ForgotPasswordView(APIView):
    """Sends a password reset email with a secure token link."""
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email', '').strip()
        if not email:
            return Response({'error': 'Email is required.'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            user = Account.objects.get(email=email)
        except Account.DoesNotExist:
            # Return success to avoid user enumeration
            return Response({'message': 'If this email is registered, a reset link has been sent.'})

        uid = urlsafe_base64_encode(force_bytes(user.pk))
        token = default_token_generator.make_token(user)
        reset_link = f'{settings.FRONTEND_URL}#/reset-password/{uid}/{token}/'

        try:
            send_mail(
                subject='EMS — Password Reset Request',
                message=(
                    f'Hi {_get_display_name(user)},\n\n'
                    f'Click the link below to reset your password:\n{reset_link}\n\n'
                    f'This link expires in 24 hours. If you did not request a reset, ignore this email.'
                ),
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                fail_silently=False,
            )
        except Exception as e:
            return Response({'error': f'Failed to send email: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        return Response({'message': 'If this email is registered, a reset link has been sent.'})


class PasswordResetConfirmView(APIView):
    """Validates reset token and sets a new password."""
    permission_classes = [AllowAny]

    def post(self, request):
        uid = request.data.get('uid')
        token = request.data.get('token')
        new_password = request.data.get('new_password', '')

        if not uid or not token or not new_password:
            return Response({'error': 'uid, token, and new_password are required.'}, status=status.HTTP_400_BAD_REQUEST)
        if len(new_password) < 6:
            return Response({'error': 'Password must be at least 6 characters.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user_id = force_str(urlsafe_base64_decode(uid))
            user = Account.objects.get(pk=user_id)
        except (TypeError, ValueError, Account.DoesNotExist):
            return Response({'error': 'Invalid reset link.'}, status=status.HTTP_400_BAD_REQUEST)

        if not default_token_generator.check_token(user, token):
            return Response({'error': 'Reset link is invalid or has expired.'}, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(new_password)
        user.save()
        return Response({'message': 'Password reset successfully. You can now log in.'})