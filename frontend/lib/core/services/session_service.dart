import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../providers/session_provider.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Service responsible for tracking user interactions, evaluating role-based
/// inactivity timeouts, and enforcing work-schedule session rules.
class SessionService {
  final Ref _ref;
  DateTime _lastActivityTime = DateTime.now();
  Timer? _evalTimer;
  bool _isExpiring = false;

  SessionService(this._ref);

  DateTime get lastActivityTime => _lastActivityTime;

  /// Records any user interaction (touch, click, mouse movement, keypress, scroll).
  void recordActivity() {
    _lastActivityTime = DateTime.now();
  }

  /// Starts the periodic background session evaluation timer (runs every 15s).
  void start() {
    _evalTimer?.cancel();
    _lastActivityTime = DateTime.now();
    _evalTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      evaluateSession();
    });
  }

  /// Evaluates current session validity against user role, inactivity duration,
  /// and work-shift schedule.
  void evaluateSession() {
    if (_isExpiring) return;

    final authState = _ref.read(authProvider);
    if (!authState.isAuthenticated || authState.user == null) {
      return;
    }

    final user = authState.user!;
    final now = DateTime.now();
    final idleSeconds = now.difference(_lastActivityTime).inSeconds;
    final idleMinutes = idleSeconds / 60.0;

    // ── 1. Admin Session Evaluation ──────────────────────────────────────────
    if (user.canManage) {
      if (idleMinutes >= AppConstants.adminInactivityTimeoutMinutes) {
        if (kDebugMode) {
          debugPrint('🔒 Admin session expired: $idleMinutes min idle (limit: ${AppConstants.adminInactivityTimeoutMinutes}m)');
        }
        expireSession(
          'Your admin session has expired due to ${AppConstants.adminInactivityTimeoutMinutes} minutes of inactivity.',
        );
      }
      return;
    }

    // ── 2. Employee Session Evaluation (Schedule-Aware) ──────────────────────
    final isWorkDay = AppConstants.workDays.contains(now.weekday);
    final currentMinuteOfDay = now.hour * 60 + now.minute;
    const workStartMinute = AppConstants.workHourStartHour * 60 + AppConstants.workHourStartMinute; // 10:00 AM (600)
    const workEndMinute = AppConstants.workHourEndHour * 60 + AppConstants.workHourEndMinute;       // 05:30 PM (1050)

    final isWithinShiftHours = isWorkDay && (currentMinuteOfDay >= workStartMinute && currentMinuteOfDay < workEndMinute);

    if (isWithinShiftHours) {
      // During official shift hours (10:00 AM – 5:30 PM on workdays),
      // the employee session NEVER expires due to inactivity.
      return;
    }

    // Off-Hours: Before 10:00 AM, after 5:30 PM, or on weekly off-days (e.g., Saturday)
    if (idleMinutes >= AppConstants.employeeOffHoursInactivityTimeoutMinutes) {
      final String offHoursDetail;
      if (!isWorkDay) {
        offHoursDetail = 'outside weekly working days';
      } else if (currentMinuteOfDay < workStartMinute) {
        offHoursDetail = 'before 10:00 AM shift start';
      } else {
        offHoursDetail = 'after 5:30 PM shift end';
      }

      if (kDebugMode) {
        debugPrint('🔒 Employee session expired ($offHoursDetail): $idleMinutes min idle (limit: ${AppConstants.employeeOffHoursInactivityTimeoutMinutes}m)');
      }

      expireSession(
        'Your session has expired due to inactivity ($offHoursDetail). Please log in again.',
      );
    }
  }

  /// Terminates the current session, registers the expiry reason, and logs out.
  Future<void> expireSession(String reason) async {
    if (_isExpiring) return;
    _isExpiring = true;

    try {
      _ref.read(sessionExpiredMessageProvider.notifier).state = reason;
      await _ref.read(authProvider.notifier).logout();
    } finally {
      _isExpiring = false;
      _lastActivityTime = DateTime.now();
    }
  }

  void dispose() {
    _evalTimer?.cancel();
    _evalTimer = null;
  }
}
