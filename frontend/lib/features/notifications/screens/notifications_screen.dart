import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/notification_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

IconData _notifIcon(String? type) {
  switch (type?.toLowerCase()) {
    case 'task':
      return Iconsax.task_square;
    case 'leave':
      return Iconsax.calendar_remove;
    case 'salary':
    case 'payroll':
      return Iconsax.wallet_money;
    case 'performance':
      return Iconsax.star_1;
    case 'feedback':
      return Iconsax.message_question;
    case 'calendar':
      return Iconsax.calendar;
    case 'notice':
      return Iconsax.notification_bing;
    default:
      return Iconsax.notification;
  }
}

Color _notifColor(String? type) {
  switch (type?.toLowerCase()) {
    case 'task':
      return const Color(0xFF0EA5E9); // Cyan / Sky
    case 'leave':
      return const Color(0xFFF59E0B); // Amber
    case 'salary':
    case 'payroll':
      return const Color(0xFF10B981); // Emerald
    case 'performance':
      return const Color(0xFF8B5CF6); // Purple
    case 'feedback':
      return AppColors.primary; // Indigo
    case 'calendar':
      return const Color(0xFF06B6D4);
    default:
      return AppColors.primary;
  }
}

String _relativeTime(String? createdAt) {
  if (createdAt == null) return '';
  try {
    final dt = DateTime.parse(createdAt).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return '';
  }
}

String _dateGroup(String? createdAt) {
  if (createdAt == null) return 'Older';
  try {
    final dt = DateTime.parse(createdAt).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (today.difference(d).inDays < 7) return 'This week';
    return 'Older';
  } catch (_) {
    return 'Older';
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedType = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiService().post('${AppConstants.notificationsBase}/mark-all-read/', data: {});
      Future.microtask(() {
        if (mounted) ref.read(unreadCountProvider.notifier).state = 0;
      });
    } catch (_) {}
  }

  Future<void> _deleteNotification(int id) async {
    try {
      await ApiService().delete('${AppConstants.notificationsBase}/$id/');
      ref.invalidate(notificationsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete: ${ApiService.getErrorMessage(e)}'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _showNotificationDetail(Map n) {
    final title = n['title'] ?? 'Notification';
    final message = n['message'] ?? '';
    final type = n['notification_type']?.toString();
    final color = _notifColor(type);
    final icon = _notifIcon(type);
    final timeAgo = _relativeTime(n['created_at']?.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        (type ?? 'General').toUpperCase(),
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Iconsax.close_circle, size: 20),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: context.textPrimary,
              ),
            ),
            if (timeAgo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Received $timeAgo',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 14),
            Divider(color: context.border),
            const SizedBox(height: 14),
            SelectableText(
              message,
              style: TextStyle(fontSize: 14, color: context.textPrimary, height: 1.6),
            ),
            const SizedBox(height: 24),
            if (n['id'] != null)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteNotification(n['id'] as int);
                },
                icon: const Icon(Iconsax.trash, size: 16, color: AppColors.error),
                label: const Text('Delete Notification', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifs = ref.watch(notificationsProvider);
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: notifs.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(
            child: Container(
              padding: const EdgeInsets.all(28),
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.warning_2, color: AppColors.error, size: 48),
                  const SizedBox(height: 14),
                  Text('Failed to load notifications: ${ApiService.getErrorMessage(e)}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(notificationsProvider),
                    icon: const Icon(Iconsax.refresh, size: 16),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          data: (list) {
            final unreadCount = list.where((n) => n['is_read'] != true).length;

            // Filter by type & search
            final filtered = list.where((n) {
              final type = (n['notification_type'] ?? 'general').toString().toLowerCase();
              if (_selectedType != 'all' && type != _selectedType.toLowerCase()) {
                return false;
              }
              if (_searchQuery.isEmpty) return true;
              final title = (n['title'] ?? '').toString().toLowerCase();
              final msg = (n['message'] ?? '').toString().toLowerCase();
              final query = _searchQuery.toLowerCase();
              return title.contains(query) || msg.contains(query);
            }).toList();

            // Group by date label
            final groups = <String, List<dynamic>>{};
            for (final n in filtered) {
              final group = _dateGroup(n['created_at']?.toString());
              groups.putIfAbsent(group, () => []).add(n);
            }
            final groupOrder = ['Today', 'Yesterday', 'This week', 'Older'];
            final sortedGroups = groupOrder.where((g) => groups.containsKey(g)).toList();

            return LayoutBuilder(
              builder: (context, constraints) {
                final isTight = constraints.maxWidth < 650;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTight ? 14 : 24,
                    vertical: isTight ? 16 : 24,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Top Header Card ────────────────────────────────────
                          Container(
                            padding: EdgeInsets.all(isTight ? 14 : 20),
                            decoration: BoxDecoration(
                              color: context.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: context.border, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(isTight ? 9 : 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(Iconsax.notification_bing,
                                          color: AppColors.primary, size: isTight ? 20 : 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'Activity & Alerts',
                                              style: TextStyle(
                                                fontSize: isTight ? 17 : 20,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.4,
                                                color: context.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (unreadCount > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.error.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '$unreadCount New',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.error,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (list.isNotEmpty && !isTight) ...[
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          await _markAllAsRead();
                                          ref.invalidate(notificationsProvider);
                                        },
                                        icon: const Icon(Iconsax.tick_circle, size: 16, color: AppColors.primary),
                                        label: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.w700)),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    IconButton(
                                      icon: const Icon(Iconsax.refresh, size: 18),
                                      tooltip: 'Refresh Notifications',
                                      onPressed: () => ref.invalidate(notificationsProvider),
                                      style: IconButton.styleFrom(
                                        backgroundColor: context.card,
                                        side: BorderSide(color: context.border),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ),
                                  ],
                                ),
                                if (list.isNotEmpty && isTight) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        await _markAllAsRead();
                                        ref.invalidate(notificationsProvider);
                                      },
                                      icon: const Icon(Iconsax.tick_circle, size: 15, color: AppColors.primary),
                                      label: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  'Task deliverables, leave approvals & corporate announcements',
                                  style: TextStyle(fontSize: isTight ? 11.5 : 12, color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                      const SizedBox(height: 20),

                      // ── Search & Filter Controls ───────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.border, width: 1),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search notification messages...',
                                prefixIcon: const Icon(Iconsax.search_normal, size: 20),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Iconsax.close_circle, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (v) => setState(() => _searchQuery = v),
                            ),
                            const SizedBox(height: 12),

                            // Type Filter Pills
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildTypeFilterChip('all', 'All Alerts', AppColors.primary, Iconsax.category),
                                  _buildTypeFilterChip('task', 'Tasks', const Color(0xFF0EA5E9), Iconsax.task_square),
                                  _buildTypeFilterChip('leave', 'Leaves', const Color(0xFFF59E0B), Iconsax.calendar_remove),
                                  _buildTypeFilterChip('salary', 'Payroll', const Color(0xFF10B981), Iconsax.wallet_money),
                                  _buildTypeFilterChip('feedback', 'Feedback', AppColors.primary, Iconsax.message_question),
                                  _buildTypeFilterChip('notice', 'Notices', const Color(0xFF8B5CF6), Iconsax.notification),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Notifications Grouped Stream ───────────────────────
                      if (filtered.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: context.border),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Iconsax.notification_bing, size: 48, color: AppColors.primary),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty ? 'No notifications matching "$_searchQuery"' : 'All caught up!',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'You have no pending alerts or unread notifications at this time.',
                                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      else
                        ...sortedGroups.map((group) {
                          final items = groups[group]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 8, bottom: 10, left: 4),
                                child: Text(
                                  group.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              ...items.map((n) => _NotificationTile(
                                    notification: n,
                                    onTap: () => _showNotificationDetail(n),
                                    onDelete: () => _deleteNotification(n['id'] as int),
                                  )),
                              const SizedBox(height: 8),
                            ],
                          );
                        }),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  ),
);
  }

  Widget _buildTypeFilterChip(String key, String label, Color color, IconData icon) {
    final isSelected = _selectedType.toLowerCase() == key.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedType = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.15) : context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : context.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: isSelected ? color : AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? color : context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Notification Tile ───────────────────────────────────────────────────────
class _NotificationTile extends StatelessWidget {
  final Map notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final isRead = n['is_read'] == true;
    final type = n['notification_type']?.toString();
    final color = _notifColor(type);
    final icon = _notifIcon(type);
    final timeAgo = _relativeTime(n['created_at']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRead ? context.border : color.withValues(alpha: 0.4),
          width: isRead ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              (n['title'] != null && n['title'].toString().trim().isNotEmpty)
                                  ? n['title'].toString().trim()
                                  : 'System Notification',
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                                fontSize: 14.5,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeAgo,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      if (n['message'] != null && n['message'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          n['message'].toString().trim(),
                          style: TextStyle(
                            fontSize: 13,
                            color: isRead ? AppColors.textSecondary : context.textPrimary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Iconsax.trash, size: 16, color: AppColors.textSecondary),
                  tooltip: 'Delete notification',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
