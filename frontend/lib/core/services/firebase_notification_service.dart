import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // App is in background/terminated, FCM handles the system notification tray.
}

class FirebaseNotificationService {
  static final FirebaseNotificationService _instance = FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  late final FirebaseMessaging _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (_) {}
    _fcm = FirebaseMessaging.instance;
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    // Request permissions (iOS/Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission for notifications');
    }

    if (!kIsWeb) {
      // Setup Local Notifications for FOREGROUND messages
      const AndroidInitializationSettings androidInitSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings =
          InitializationSettings(android: androidInitSettings);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          _handleNotificationTap(details.payload);
        },
      );
    }

    // Listen for messages while app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        if (!kIsWeb) {
          _showLocalNotification(message);
        }
      }
    });

    // Handle tap when app is opened from background/terminated via FCM tray
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(jsonEncode(message.data));
    });

    _isInitialized = true;
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ems_main_channel',
      'EMS Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformDetails,
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload);
      debugPrint("Notification tapped with payload: $data");
      // Add logic here to navigate using GoRouter depending on data['type']
      // e.g. if type == 'task', GoRouter.of(context).go('/tasks')
    } catch (e) {
      debugPrint("Error parsing payload: $e");
    }
  }

  Future<void> registerDeviceToken() async {
    // Called only when authenticated by AuthProvider
    if (kIsWeb) return;

    try {
      final fcmToken = await _fcm.getToken();
      if (fcmToken != null) {
        debugPrint("FCM Token: $fcmToken");
        final api = ApiService();
        await api.post('/api/notifications/device-token/', data: {'token': fcmToken});
      }
    } catch (e) {
      debugPrint("Failed to register FCM token: $e");
    }
  }

}




