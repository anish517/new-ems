import 'package:ems_app/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/notification_provider.dart';

import '../../../core/constants/app_constants.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiService().post('${AppConstants.notificationsBase}/mark-all-read/', data: {});
      // Delay slightly to ensure provider update happens after build phase
      Future.microtask(() {
        ref.read(unreadCountProvider.notifier).state = 0;
      });
    } catch (_) {}
  }

  Future<void> _deleteNotification(int id) async {
    try {
      await ApiService().delete('${AppConstants.notificationsBase}/$id/');
      ref.invalidate(notificationsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${ApiService.getErrorMessage(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifs = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notifs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error: ${ApiService.getErrorMessage(e)}')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No notifications'))
            : RefreshIndicator(
                onRefresh: () async => ref.refresh(notificationsProvider.future),
                child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final n = list[i];
                      return Dismissible(
                        key: ValueKey(n['id']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: AppColors.error,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteNotification(n['id']),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: (n['is_read'] == true)
                                ? context.card
                                : AppColors.primary,
                            child: const Icon(Icons.notifications_outlined,
                                color: Colors.white, size: 18),
                          ),
                          title: Text(n['title'] ?? ''),
                          subtitle: Text(n['message'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            onPressed: () => _deleteNotification(n['id']),
                          ),
                        ),
                      );
                    }),
              ),
      ),
    );
  }
}




