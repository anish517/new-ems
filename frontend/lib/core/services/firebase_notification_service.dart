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
  // NOTE: only the small icon (from AndroidManifest's default_notification_icon)
  // is shown in this path — the large/color icon cannot be applied here unless
  // you switch to data-only messages and build the notification yourself.
}

class FirebaseNotificationService {
  static final FirebaseNotificationService _instance =
      FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  late final FirebaseMessaging _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

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
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    }

    // Request permissions (iOS/Android 13+)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Configure foreground presentation options
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (!kIsWeb) {
      // Setup Local Notifications for FOREGROUND messages
      const AndroidInitializationSettings androidInitSettings =
          AndroidInitializationSettings(
              'ic_stat_notify'); // small white status-bar icon (required)
      const InitializationSettings initSettings =
          InitializationSettings(android: androidInitSettings);

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'ems_main_channel',
            'EMS Notifications',
            description: 'Main channel for EMS push notifications',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          _handleNotificationTap(details.payload);
        },
      );
    }

    // Listen for messages while app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? message.data['title'];
      debugPrint('Got a message whilst in the foreground: $title');
      if (!kIsWeb) {
        _showLocalNotification(message);
      }
    });

    // Handle tap when app is opened from background/terminated via FCM tray
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(jsonEncode(message.data));
    });

    _isInitialized = true;
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'] ?? message.data['message'];
    if (title == null && body == null) return;

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'ems_main_channel',
        'EMS Notifications',
        channelDescription: 'Main channel for EMS push notifications',
        icon: 'ic_stat_notify', // small icon — status bar, white, required
        largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'),
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
      );
      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        platformDetails,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      debugPrint('Error showing local notification with custom icons: $e');
      try {
        const AndroidNotificationDetails fallbackDetails =
            AndroidNotificationDetails(
          'ems_main_channel',
          'EMS Notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );
        await _localNotifications.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          const NotificationDetails(android: fallbackDetails),
          payload: jsonEncode(message.data),
        );
      } catch (e2) {
        debugPrint('Error showing fallback local notification: $e2');
      }
    }
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
        await api.post('/api/notifications/device-token/',
            data: {'token': fcmToken});
      }
    } catch (e) {
      debugPrint("Failed to register FCM token: $e");
    }
  }
}
