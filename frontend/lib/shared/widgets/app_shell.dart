import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final isAdmin = user?.canManage ?? false;

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
      _NavItem('/leave', Iconsax.calendar_remove, 'Leaves'),
      _NavItem('/salary', Iconsax.money, 'Salary'),
      _NavItem('/tasks', Iconsax.task_square, 'Tasks'),
      _NavItem('/performance', Iconsax.star1, 'Performance'),
      _NavItem('/noticeboard', Iconsax.message_text, 'Notices'),
      _NavItem('/calendar', Iconsax.calendar, 'Calendar'),
      _NavItem('/feedback', Iconsax.message_question, 'Feedback'),
      _NavItem('/profile', Iconsax.user, 'Profile'),
    ];

    final navItems = isAdmin ? adminNav : employeeNav;
    final currentIndex =
        navItems.indexWhere((i) => location.startsWith(i.route));
    final isMobile = MediaQuery.of(context).size.width < 700;

    Widget sidebarContent = Container(
      color: AppColors.surfaceDark,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(Iconsax.box, color: AppColors.primary, size: 32),
                  SizedBox(width: 12),
                  Text('EMS',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: navItems.length,
                itemBuilder: (context, i) {
                  final item = navItems[i];
                  final isSelected = currentIndex == i;
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    child: InkWell(
                      onTap: () {
                        if (isMobile) Navigator.pop(context);
                        context.go(item.route);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(item.icon,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                size: 20),
                            const SizedBox(width: 16),
                            Text(item.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                )),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: () => ref.read(authProvider.notifier).logout(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Iconsax.logout, color: AppColors.error, size: 20),
                      SizedBox(width: 16),
                      Text('Log out',
                          style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // ── Mobile: use Drawer + BottomNavigationBar ───────────────────────────────
    if (isMobile) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        drawer: Drawer(
          width: 260,
          backgroundColor: AppColors.surfaceDark,
          child: sidebarContent,
        ),
        appBar: AppBar(
          backgroundColor: AppColors.surfaceDark,
          elevation: 0,
          leading: Builder(
              builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  )),
          title: const Text('EMS',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          actions: [
            IconButton(
              icon: const Icon(Iconsax.notification, color: Colors.white),
              onPressed: () => context.go('/notifications'),
            ),
            GestureDetector(
              onTap: () => context.go('/profile'),
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  backgroundImage: user?.profilePicture != null
                      ? NetworkImage(user!.profilePicture!)
                      : null,
                  child: user?.profilePicture == null
                      ? Text(
                          user?.firstName.isNotEmpty == true
                              ? user!.firstName[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
        body: child,
      );
    }

    // ── Desktop/Tablet: permanent sidebar ─────────────────────────────────────
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Row(
        children: [
          SizedBox(width: 200, child: sidebarContent),
          Expanded(child: child),
        ],
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
