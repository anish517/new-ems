import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

// Holds the live unread badge count. Reset to 0 on logout by auth_provider.
final unreadCountProvider = StateProvider<int>((ref) => 0);

final notificationsProvider = FutureProvider<List>((ref) async {
  // Use a periodic timer so the badge stays fresh every 30s on web/desktop
  // (where FCM push doesn't fire). The timer is cancelled when the provider
  // is disposed (e.g. on logout when ProviderScope is rebuilt).
  Timer? timer;
  timer = Timer.periodic(const Duration(seconds: 30), (_) {
    ref.invalidateSelf();
  });
  ref.onDispose(() => timer?.cancel());

  final res = await ApiService().get('${AppConstants.notificationsBase}/list/');

  // Safely handle both plain List and paginated { results: [...] } responses
  final rawData = (res.data is List
      ? res.data
      : (res.data['results'] ?? [])) as List;

  // Filter out any empty/malformed notification items
  final data = rawData.where((n) {
    if (n is! Map) return false;
    final title = n['title']?.toString().trim() ?? '';
    final msg = n['message']?.toString().trim() ?? '';
    return title.isNotEmpty || msg.isNotEmpty;
  }).toList();

  // Update the badge count — only write if the value actually changed
  // to avoid unnecessary widget rebuilds.
  final unread = data.where((n) => n['is_read'] != true).length;
  final current = ref.read(unreadCountProvider);
  if (current != unread) {
    ref.read(unreadCountProvider.notifier).state = unread;
  }
  return data;
});
