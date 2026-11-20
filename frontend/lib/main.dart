import 'package:ems_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/firebase_notification_service.dart';
import 'shared/widgets/session_inactivity_listener.dart';

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

    return MaterialApp.router(
      title: 'EMS — Employee Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      scrollBehavior: AppScrollBehavior(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        // Clamp OS text scaling inside MaterialApp.builder so Flutter's own
        // reactive MediaQuery.fromView stays active for keyboard viewInsets,
        // screen resizes, and orientation changes.
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.noScaling,
        ),
        child: SessionInactivityListener(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
