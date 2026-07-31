import 'package:ems_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/firebase_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize FCM Notification service
  final notificationService = FirebaseNotificationService();
  await notificationService.init();

  runApp(const ProviderScope(child: EmsApp()));
}

class EmsApp extends ConsumerWidget {
  const EmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MediaQuery(
      // Clamp the OS text scale so Windows 125%/150% DPI settings don't
      // produce tiny or oversized text. We allow a gentle max of 1.2× for
      // accessibility while keeping the design looking professional.
      data: MediaQueryData.fromView(View.of(context)).copyWith(
        textScaler: TextScaler.noScaling,
      ),
      child: MaterialApp.router(
        title: 'EMS — Employee Management',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        scrollBehavior: AppScrollBehavior(),
        routerConfig: router,
      ),
    );
  }
}




