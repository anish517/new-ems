import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/dashboard/screens/employee_dashboard.dart';
import '../features/dashboard/screens/admin_dashboard.dart';
import '../features/attendance/screens/attendance_screen.dart';
import '../features/leave/screens/leave_screen.dart';
import '../features/salary/screens/salary_screen.dart';
import '../features/tasks/screens/tasks_screen.dart';
import '../features/noticeboard/screens/noticeboard_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/employee/screens/employee_list_screen.dart';
import '../features/feedback/screens/feedback_screen.dart';
import '../features/calendar/screens/calendar_screen.dart';
import '../shared/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn  = authState.isAuthenticated;
      final isLoading   = authState.isLoading;
      final onLoginPage = state.matchedLocation == '/login';

      if (isLoading) return null;
      if (!isLoggedIn && !onLoginPage) return '/login';
      if (isLoggedIn  &&  onLoginPage) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) {
              final user = ref.read(currentUserProvider);
              return user?.canManage == true
                  ? const AdminDashboard()
                  : const EmployeeDashboard();
            },
          ),
          GoRoute(path: '/attendance',   builder: (_, __) => const AttendanceScreen()),
          GoRoute(path: '/leave',        builder: (_, __) => const LeaveScreen()),
          GoRoute(path: '/salary',       builder: (_, __) => const SalaryScreen()),
          GoRoute(path: '/tasks',        builder: (_, __) => const TasksScreen()),
          GoRoute(path: '/noticeboard',  builder: (_, __) => const NoticeboardScreen()),
          GoRoute(path: '/notifications',builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/profile',      builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/employees',    builder: (_, __) => const EmployeeListScreen()),
          GoRoute(path: '/feedback',     builder: (_, __) => const FeedbackScreen()),
          GoRoute(path: '/calendar',     builder: (_, __) => const CalendarScreen()),
        ],
      ),
    ],
  );
});
