import os
import firebase_admin
from firebase_admin import credentials, messaging

# Initialize Firebase Admin SDK once
_initialized = False

def _init_firebase():
    global _initialized
    if not _initialized:
        cred_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'firebase-service-account.json')
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        _initialized = True


def _remove_token(device_token: str):
    """Delete a dead/invalid device token so it isn't retried again."""
    try:
        from notification.models import DeviceToken
        DeviceToken.objects.filter(token=device_token).delete()
        print('[FCM] Removed invalid token from DB.')
    except Exception:
        pass


def send_push_notification(device_token: str, title: str, body: str, data: dict = None):
    """
    Send a real FCM push notification to a device.
    Returns True on success, False on failure.
    """
    if not device_token:
        return False
    try:
        _init_firebase()
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id='ems_main_channel',
                    priority='max',
                    default_sound=True,
                    default_vibrate_timings=True,
                    icon='ic_stat_notify',
                ),
            ),
            apns=messaging.APNSConfig(
                headers={'apns-priority': '10'},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(title=title, body=body),
                        badge=1,
                        sound='default',
                        content_available=True,
                    )
                )
            ),
            token=device_token,
        )
        messaging.send(message)
        return True
    except messaging.UnregisteredError:
        # Token is dead (app uninstalled / data cleared / token rotated).
        # Caught by exception type since the string repr ("NotRegistered")
        # doesn't reliably match the fallback string checks below.
        print(f'[FCM] Token unregistered, removing: {device_token[:12]}...')
        _remove_token(device_token)
        return False
    except Exception as e:
        err_str = str(e)
        print(f'[FCM] Error sending push notification: {e}')
        # Fallback string match for any other invalid-token error shapes
        if 'registration token' in err_str.lower() or 'not a valid' in err_str.lower() or 'unregistered' in err_str.lower():
            _remove_token(device_token)
        return False


def notify_user(user, title: str, body: str, notification_type: str = 'general', reference_id: int = None):
    """
    Create a DB Notification record and send FCM push to all user devices.
    """
    from notification.models import Notification, DeviceToken

    # Save to DB (for in-app notification bell)
    Notification.objects.create(
        user=user,
        title=title,
        message=body,
        notification_type=notification_type,
        reference_id=reference_id,
        is_read=False,
    )

    # Send FCM push to all registered devices for this user
    tokens = DeviceToken.objects.filter(user=user).values_list('token', flat=True)
    for token in tokens:
        send_push_notification(token, title, body, data={
            'type': notification_type,
            'reference_id': str(reference_id or ''),
        })