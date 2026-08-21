import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/notifications/providers/notification_provider.dart';
import '../../core/theme/app_theme.dart';
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
      _NavItem('/projects', Iconsax.folder_open, 'Projects'),
      _NavItem('/salary', Iconsax.wallet_3, 'Payslips'),
      _NavItem('/noticeboard', Iconsax.message_text, 'Notices'),
      _NavItem('/policy', Iconsax.document_text, 'Policy'),
      _NavItem('/calendar', Iconsax.calendar, 'Calendar'),
      _NavItem('/feedback', Iconsax.message_question, 'Feedback'),
      _NavItem('/profile', Iconsax.user, 'Profile'),
    ];

    final adminNav = [
      _NavItem('/', Iconsax.home_2, 'Dashboard'),
      _NavItem('/employees', Iconsax.people, 'Employees'),
      _NavItem('/attendance', Iconsax.clock, 'Attendance'),
      _NavItem('/leave', Iconsax.calendar_remove, 'Leaves'),
      _NavItem('/salary', Iconsax.wallet_3, 'Accounts'),
      _NavItem('/tasks', Iconsax.task_square, 'Tasks'),
      _NavItem('/projects', Iconsax.folder_open, 'Projects'),
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    Widget sidebarContent = Container(
      color: context.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 38,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.box, color: AppColors.primary, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            // Fiscal Calendar Filter Picker
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: GlobalMonthYearPicker(),
            ),
            const SizedBox(height: 6),

            // Notification Navigation Item
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: InkWell(
                onTap: () {
                  if (isMobile) Navigator.pop(context);
                  context.go('/notifications');
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: location == '/notifications'
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Badge(
                        isLabelVisible: unreadCount > 0,
                        backgroundColor: AppColors.primary,
                        label: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        child: Icon(
                          Iconsax.notification,
                          color: location == '/notifications' || unreadCount > 0
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Notifications',
                        style: TextStyle(
                          color: location == '/notifications'
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: location == '/notifications' ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),
            Divider(color: context.border, indent: 14, endIndent: 14),
            const SizedBox(height: 4),

            // Main Nav Items List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: navItems.length,
                itemBuilder: (context, i) {
                  final item = navItems[i];
                  final isSelected = currentIndex == i;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (isMobile) Navigator.pop(context);
                          context.go(item.route);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                size: 19,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    color: isSelected ? AppColors.primary : context.textPrimary,
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            Divider(color: context.border, indent: 14, endIndent: 14),

            // User Info & Theme Footer Card
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: AppColors.primary,
                      backgroundImage: user?.profilePicture != null
                          ? NetworkImage(user!.profilePicture!)
                          : null,
                      child: user?.profilePicture == null
                          ? Text(
                              user?.firstName.isNotEmpty == true
                                  ? user!.firstName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user?.fullName.isNotEmpty == true ? user!.fullName : 'My Account',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: context.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isAdmin ? 'Administrator' : 'Team Member',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const ThemeToggleBtn(),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Iconsax.logout, color: AppColors.error, size: 18),
                      tooltip: 'Log out',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // ── Mobile View ──────────────────────────────────────────────────────────
    if (isMobile) {
      final primaryMobileItems = isAdmin
          ? [
              _NavItem('/', Iconsax.home_2, 'Home'),
              _NavItem('/employees', Iconsax.people, 'Staff'),
              _NavItem('/attendance', Iconsax.clock, 'Attendance'),
              _NavItem('/leave', Iconsax.calendar_remove, 'Leaves'),
              _NavItem('/salary', Iconsax.wallet_3, 'Accounts'),
              _NavItem('/more', Iconsax.element_plus, 'More'),
            ]
          : [
              _NavItem('/', Iconsax.home_2, 'Home'),
              _NavItem('/attendance', Iconsax.clock, 'Attendance'),
              _NavItem('/leave', Iconsax.calendar_remove, 'Leave'),
              _NavItem('/tasks', Iconsax.task_square, 'Tasks'),
              _NavItem('/more', Iconsax.element_plus, 'More'),
            ];

      final bottomIndex = primaryMobileItems.indexWhere((i) {
        if (i.route == '/more') return false;
        if (i.route == '/') return location == '/';
        return location.startsWith(i.route);
      });

      return Scaffold(
        backgroundColor: context.bg,
        drawer: Drawer(
          backgroundColor: context.surface,
          child: sidebarContent,
        ),
        appBar: AppBar(
          backgroundColor: context.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Iconsax.menu_1, color: AppColors.primary, size: 22),
              tooltip: 'Open Navigation Drawer',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 30,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Iconsax.box, color: AppColors.primary, size: 18),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                backgroundColor: AppColors.primary,
                label: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                child: Icon(
                  Iconsax.notification,
                  color: location == '/notifications' || unreadCount > 0
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  size: 20,
                ),
              ),
              tooltip: 'Notifications',
              onPressed: () => context.go('/notifications'),
            ),
            const ThemeToggleBtn(),
            const SizedBox(width: 8),
          ],
        ),
        body: child,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: context.surface,
            border: Border(top: BorderSide(color: context.border, width: 1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              height: 62,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(primaryMobileItems.length, (i) {
                  final item = primaryMobileItems[i];
                  final isMore = item.route == '/more';
                  final selected = !isMore && bottomIndex == i;

                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        if (isMore) {
                          _showMoreNavigationSheet(context, navItems, currentIndex, ref);
                        } else {
                          context.go(item.route);
                        }
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: 20,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(height: 3),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.label,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
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

    // ── Desktop / Tablet: permanent refined sidebar ──────────────────────────
    return Scaffold(
      backgroundColor: context.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 260, child: sidebarContent),
          Container(width: 1, color: context.border),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }

  void _showMoreNavigationSheet(
    BuildContext context,
    List<_NavItem> navItems,
    int currentIndex,
    WidgetRef ref,
  ) {
    final unreadCount = ref.read(unreadCountProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Modules & Navigation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ctx.textPrimary,
                      ),
                    ),
                    const ThemeToggleBtn(),
                  ],
                ),
                const SizedBox(height: 14),
                const GlobalMonthYearPicker(),
                const SizedBox(height: 12),
                ListTile(
                  leading: Badge(
                    isLabelVisible: unreadCount > 0,
                    backgroundColor: AppColors.primary,
                    label: Text(unreadCount.toString(),
                        style: const TextStyle(fontSize: 10)),
                    child: const Icon(Iconsax.notification,
                        color: AppColors.primary),
                  ),
                  title: const Text('Notifications',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/notifications');
                  },
                ),
                Divider(color: ctx.border),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: navItems.length,
                    itemBuilder: (ctx, i) {
                      final item = navItems[i];
                      final isSelected = currentIndex == i;

                      return ListTile(
                        leading: Icon(
                          item.icon,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        title: Text(
                          item.label,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : ctx.textPrimary,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          context.go(item.route);
                        },
                      );
                    },
                  ),
                ),
                Divider(color: ctx.border),
                ListTile(
                  leading: const Icon(Iconsax.logout, color: AppColors.error),
                  title: const Text('Log Out',
                      style: TextStyle(
                          color: AppColors.error, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavItem {
  final String route;
  final IconData icon;
  final String label;
  _NavItem(this.route, this.icon, this.label);
}
