import 'package:ems_app/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/notification_provider.dart';
import '../../../core/constants/app_constants.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

IconData _notifIcon(String? type) {
  switch (type) {
    case 'task':
      return Iconsax.task_square;
    case 'leave':
      return Iconsax.calendar_remove;
    case 'performance':
      return Iconsax.star1;
    case 'feedback':
      return Iconsax.message_question;
    case 'calendar':
      return Iconsax.calendar;
    default:
      return Iconsax.notification;
  }
}

Color _notifColor(String? type) {
  switch (type) {
    case 'task':
      return AppColors.accent;
    case 'leave':
      return AppColors.warning;
    case 'performance':
      return const Color(0xFFf59e0b);
    case 'feedback':
      return AppColors.primary;
    case 'calendar':
      return AppColors.success;
    default:
      return AppColors.textSecondary;
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
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiService()
          .post('${AppConstants.notificationsBase}/mark-all-read/', data: {});
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

  @override
  Widget build(BuildContext context) {
    final notifs = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          notifs.maybeWhen(
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : TextButton.icon(
                    onPressed: () async {
                      await _markAllAsRead();
                      ref.invalidate(notificationsProvider);
                    },
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Mark all read'),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(notificationsProvider),
          ),
        ],
      ),
      body: notifs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.warning_2, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Error: ${ApiService.getErrorMessage(e)}',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(notificationsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.notification,
                        size: 56, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  const Text('All caught up!',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'No notifications yet.\nYou\'re up to date.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          // Group by date label
          final groups = <String, List>{};
          for (final n in list) {
            final group = _dateGroup(n['created_at']?.toString());
            groups.putIfAbsent(group, () => []).add(n);
          }
          final groupOrder = ['Today', 'Yesterday', 'This week', 'Older'];
          final sortedGroups = groupOrder
              .where((g) => groups.containsKey(g))
              .toList();

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedGroups.length,
                  itemBuilder: (_, gi) {
                    final group = sortedGroups[gi];
                    final items = groups[group]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 8, bottom: 10, left: 4),
                          child: Text(
                            group,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        ...items.map((n) => _NotificationTile(
                              notification: n,
                              onDelete: () =>
                                  _deleteNotification(n['id'] as int),
                            )),
                        if (gi < sortedGroups.length - 1)
                          const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Notification Tile ───────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final Map notification;
  final VoidCallback onDelete;

  const _NotificationTile(
      {required this.notification, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final isRead = n['is_read'] == true;
    final type = n['notification_type']?.toString();
    final color = _notifColor(type);
    final icon = _notifIcon(type);
    final timeAgo = _relativeTime(n['created_at']?.toString());

    return Dismissible(
      key: ValueKey(n['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text('Delete',
                style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isRead
              ? context.card
              : AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: isRead ? Colors.transparent : color,
              width: 4,
            ),
          ),
          boxShadow: isRead
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon bubble
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            n['title'] ?? '',
                            style: TextStyle(
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              fontSize: 14,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n['message'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: isRead
                            ? AppColors.textSecondary
                            : context.textPrimary,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isRead) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Unread',
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
