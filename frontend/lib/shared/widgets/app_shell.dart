import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../features/auth/providers/auth_provider.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user      = ref.watch(currentUserProvider);
    final location  = GoRouterState.of(context).matchedLocation;
    final isAdmin   = user?.canManage ?? false;

    final employeeNav = [
      _NavItem('/', Iconsax.home_2, 'Home'),
      _NavItem('/attendance', Iconsax.clock, 'Attendance'),
      _NavItem('/leave', Iconsax.calendar_remove, 'Leave'),
      _NavItem('/tasks', Iconsax.task_square, 'Tasks'),
      _NavItem('/profile', Iconsax.user, 'Profile'),
    ];

    final adminNav = [
      _NavItem('/', Iconsax.home_2, 'Dashboard'),
      _NavItem('/employees', Iconsax.people, 'Employees'),
      _NavItem('/attendance', Iconsax.clock, 'Attendance'),
      _NavItem('/salary', Iconsax.money, 'Salary'),
      _NavItem('/profile', Iconsax.user, 'Profile'),
    ];

    final navItems = isAdmin ? adminNav : employeeNav;
    final currentIndex = navItems.indexWhere((i) => location.startsWith(i.route));

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex < 0 ? 0 : currentIndex,
        onDestinationSelected: (i) => context.go(navItems[i].route),
        backgroundColor: Theme.of(context).colorScheme.surface,
        destinations: navItems.map((item) => NavigationDestination(
          icon: Icon(item.icon),
          label: item.label,
        )).toList(),
      ),
    );
  }
}

class _NavItem {
  final String route;
  final IconData icon;
  final String label;
  _NavItem(this.route, this.icon, this.label);
}
