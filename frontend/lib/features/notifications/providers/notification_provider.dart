import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

final unreadCountProvider = StateProvider<int>((ref) => 0);

final notificationsProvider = FutureProvider<List>((ref) async {
  final res = await ApiService().get('${AppConstants.notificationsBase}/list/');
  final data = res.data['results'] ?? res.data as List;
  final unread = (data as List).where((n) => n['is_read'] != true).length;
  ref.read(unreadCountProvider.notifier).state = unread;
  return data;
});
