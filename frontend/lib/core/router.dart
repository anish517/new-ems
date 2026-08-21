import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/attendance/screens/attendance_screen.dart';
import '../features/leave/screens/leave_screen.dart';
import '../features/accounts/screens/accounts_screen.dart';
import '../features/tasks/screens/tasks_screen.dart';
import '../features/tasks/screens/projects_screen.dart';
import '../features/noticeboard/screens/noticeboard_screen.dart';
import '../features/noticeboard/screens/policy_screen.dart';
import '../features/noticeboard/screens/policy_approval_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/employee/screens/employee_list_screen.dart';
import '../features/employee/screens/employee_detail_screen.dart';
import '../features/feedback/screens/feedback_screen.dart';
import '../features/calendar/screens/calendar_screen.dart';
import '../features/performance/screens/performance_screen.dart';
import '../shared/widgets/app_shell.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final isLoggedIn = authState.isAuthenticated;
    final isLoading = authState.isLoading;
    final user = authState.user;
    final onLoginPage = state.matchedLocation == '/login';
    final onPolicyApprovalPage = state.matchedLocation == '/policy-approval';

    if (isLoading) return null;
    if (!isLoggedIn && !onLoginPage) return '/login';
    if (!isLoggedIn && onLoginPage) return null;

    // First login Policy Approval guard for non-admin employees
    final needsPolicyApproval = user != null && !user.canManage && !user.hasApprovedPolicy;
    if (needsPolicyApproval) {
      if (!onPolicyApprovalPage) return '/policy-approval';
      return null;
    }

    if (onPolicyApprovalPage && !needsPolicyApproval) {
      return '/';
    }

    if (isLoggedIn && onLoginPage) return '/';
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/policy-approval', builder: (_, __) => const PolicyApprovalScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
              path: '/attendance',
              builder: (_, __) => const AttendanceScreen()),
          GoRoute(path: '/leave', builder: (_, __) => const LeaveScreen()),
          GoRoute(path: '/salary', builder: (_, __) => const AccountsScreen()),
          GoRoute(path: '/tasks', builder: (_, __) => const TasksScreen()),
          GoRoute(path: '/projects', builder: (_, __) => const ProjectsScreen()),
          GoRoute(
              path: '/noticeboard',
              builder: (_, __) => const NoticeboardScreen()),
          GoRoute(
              path: '/notifications',
              builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(
              path: '/employees',
              builder: (_, __) => const EmployeeListScreen()),
          GoRoute(
              path: '/employees/:id',
              builder: (context, state) => EmployeeDetailScreen(id: int.parse(state.pathParameters['id']!))),
          GoRoute(
              path: '/feedback', builder: (_, __) => const FeedbackScreen()),
          GoRoute(
              path: '/calendar', builder: (_, __) => const CalendarScreen()),
          GoRoute(
              path: '/performance',
              builder: (_, __) => const PerformanceScreen()),
          GoRoute(
              path: '/policy', builder: (_, __) => const PolicyScreen()),
        ],
      ),
    ],
  );
});
