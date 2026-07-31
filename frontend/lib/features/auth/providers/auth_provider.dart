import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firebase_notification_service.dart';
import '../../notifications/providers/notification_provider.dart';

// Auth state
class AuthState {
  final UserProfile? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({UserProfile? user, bool? isLoading, String? error}) =>
      AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final Ref _ref;

  AuthNotifier(this._authService, this._ref) : super(const AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      if (await _authService.isLoggedIn()) {
        final user = await _authService.fetchMe();
        state = AuthState(user: user);
        FirebaseNotificationService().registerDeviceToken();
      } else {
        state = const AuthState();
      }
    } catch (_) {
      state = const AuthState();
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.login(email, password);
      state = AuthState(user: user);
      // Reset notification badge and re-fetch for the newly logged-in user
      _ref.read(unreadCountProvider.notifier).state = 0;
      _ref.invalidate(notificationsProvider);
      FirebaseNotificationService().registerDeviceToken();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Invalid email or password. Please try again.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    // Reset badge and clear cached notifications before state change
    _ref.read(unreadCountProvider.notifier).state = 0;
    _ref.invalidate(notificationsProvider);
    state = const AuthState();
  }

  Future<void> refreshUser() async {
    try {
      final user = await _authService.fetchMe();
      state = AuthState(user: user);
    } catch (_) {}
  }
}

// Providers
final authServiceProvider = Provider((_) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(authServiceProvider), ref),
);

final currentUserProvider = Provider<UserProfile?>(
  (ref) => ref.watch(authProvider).user,
);
