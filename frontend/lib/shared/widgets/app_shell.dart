import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/notifications/providers/notification_provider.dart';
import '../../core/theme/app_theme.dart';
import 'global_month_year_picker.dart';
import 'common_widgets.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final isAdmin = user?.canManage ?? false;

    final employeeNav = [
      _NavItem('/', Iconsax.home_2, 'Home'),
      _NavItem('/attendance', Iconsax.clock, 'Attendance'),
      _NavItem('/leave', Iconsax.calendar_remove, 'Leave'),
      _NavItem('/tasks', Iconsax.task_square, 'Tasks'),
      _NavItem('/noticeboard', Iconsax.message_text, 'Notices'),
      _NavItem('/policy', Iconsax.document_text, 'Policy'),
      _NavItem('/profile', Iconsax.user, 'Profile'),
    ];

    final adminNav = [
      _NavItem('/', Iconsax.home_2, 'Dashboard'),
      _NavItem('/employees', Iconsax.people, 'Employees'),
      _NavItem('/attendance', Iconsax.clock, 'Attendance'),
      _NavItem('/leave', Iconsax.calendar_remove, 'Leaves'),
      _NavItem('/salary', Iconsax.money_send, 'Accounts'),
      _NavItem('/tasks', Iconsax.task_square, 'Tasks'),
      _NavItem('/performance', Iconsax.star1, 'Performance'),
      _NavItem('/noticeboard', Iconsax.message_text, 'Notices'),
      _NavItem('/policy', Iconsax.document_text, 'Policy'),
      _NavItem('/calendar', Iconsax.calendar, 'Calendar'),
      _NavItem('/feedback', Iconsax.message_question, 'Feedback'),
      _NavItem('/profile', Iconsax.user, 'Profile'),
    ];

    final navItems = isAdmin ? adminNav : employeeNav;
    final currentIndex = navItems.indexWhere((i) {
      if (i.route == '/') return location == '/';
      return location.startsWith(i.route);
    });
    final isMobile = MediaQuery.of(context).size.width < 700;

    Widget sidebarContent = Container(
      color: context.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 40,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Iconsax.box, color: AppColors.primary, size: 32),
                  ),
                  // Removed redundant 'OmWay' text since logo contains it
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GlobalMonthYearPicker(),
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
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Stack(
                          children: [
                            if (isSelected)
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 4,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.brightness_medium, color: AppColors.primary, size: 20),
                        SizedBox(width: 16),
                        Text('Theme', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const ThemeToggleBtn(),
                  ],
                ),
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

    // ── Mobile: employee gets BottomNavigationBar; admin keeps Drawer ────────
    if (isMobile) {
      if (!isAdmin) {
        // Employee mobile — bottom navigation bar
        final bottomItems = [
          _NavItem('/', Iconsax.home_2, 'Home'),
          _NavItem('/attendance', Iconsax.clock, 'Attendance'),
          _NavItem('/leave', Iconsax.calendar_remove, 'Leave'),
          _NavItem('/tasks', Iconsax.task_square, 'Tasks'),
          _NavItem('/profile', Iconsax.user, 'Profile'),
        ];
        final bottomIndex = bottomItems.indexWhere((i) {
          if (i.route == '/') return location == '/';
          return location.startsWith(i.route);
        });

        return Scaffold(
          backgroundColor: context.bg,
          appBar: AppBar(
            backgroundColor: context.surface,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Text(
              bottomIndex >= 0 ? bottomItems[bottomIndex].label : 'EMS',
              style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
            actions: [
              const ThemeToggleBtn(),
              Badge(
                isLabelVisible: unreadCount > 0,
                label: Text(unreadCount.toString()),
                child: IconButton(
                  icon: Icon(Iconsax.notification, color: context.textPrimary),
                  onPressed: () => context.go('/notifications'),
                ),
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
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: context.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                height: 64,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(bottomItems.length, (i) {
                    final item = bottomItems[i];
                    final selected = bottomIndex == i;
                    return Expanded(
                      child: InkWell(
                        onTap: () => context.go(item.route),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              size: 22,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        );
      }

      // Admin mobile — keeps Drawer
      return Scaffold(
        backgroundColor: context.bg,
        drawer: Drawer(
          width: 260,
          backgroundColor: context.surface,
          child: sidebarContent,
        ),
        appBar: AppBar(
          backgroundColor: context.surface,
          elevation: 0,
          leading: Builder(
              builder: (ctx) => IconButton(
                    icon: Icon(Icons.menu, color: context.textPrimary),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  )),
          title: Text('EMS',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
          actions: [
            const ThemeToggleBtn(),
            Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount.toString()),
              child: IconButton(
                icon: Icon(Iconsax.notification, color: context.textPrimary),
                onPressed: () => context.go('/notifications'),
              ),
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
      backgroundColor: context.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 250, child: sidebarContent), // Increased width slightly for better text fit
          // Divider between sidebar and main content
          Container(width: 1, color: context.border),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: child,
                ),
              ),
            ),
          ),
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





