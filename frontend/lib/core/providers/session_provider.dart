import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/session_service.dart';

/// Holds a message explaining why the session expired (if any) to display on the login screen.
final sessionExpiredMessageProvider = StateProvider<String?>((ref) => null);

/// Tracks the timestamp of the last detected user interaction.
final lastActivityTimestampProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Provider for the singleton SessionService.
final sessionServiceProvider = Provider<SessionService>((ref) {
  final service = SessionService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
