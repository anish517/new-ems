import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

final unreadCountProvider = StateProvider<int>((ref) => 0);


final notificationsProvider = FutureProvider<List>((ref) async {
  // Poll every 30 seconds to keep badges updated (especially useful for Web/Windows without FCM)
  final timer = Timer(const Duration(seconds: 30), () {
    if (!ref.state.isLoading && !ref.state.isRefreshing) {
      ref.invalidateSelf();
    }
  });
  
  ref.onDispose(() => timer.cancel());

  final res = await ApiService().get('${AppConstants.notificationsBase}/list/');
  // Safely handle both plain List and paginated { results: [...] } responses
  final data = (res.data is List
      ? res.data
      : (res.data['results'] ?? [])) as List;
  final unread = data.where((n) => n['is_read'] != true).length;
  ref.read(unreadCountProvider.notifier).state = unread;
  return data;
});




