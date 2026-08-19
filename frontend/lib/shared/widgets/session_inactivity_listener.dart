import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/session_provider.dart';

/// Global widget that wraps the entire app to capture user interactions
/// (mouse moves, clicks, touches, scrolls, and key presses) and feed them to
/// the [SessionService] to keep the inactivity timer accurate.
class SessionInactivityListener extends ConsumerStatefulWidget {
  final Widget child;

  const SessionInactivityListener({super.key, required this.child});

  @override
  ConsumerState<SessionInactivityListener> createState() =>
      _SessionInactivityListenerState();
}

class _SessionInactivityListenerState
    extends ConsumerState<SessionInactivityListener> {
  DateTime _lastThrottledRecord = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Start periodic background session evaluation
    ref.read(sessionServiceProvider).start();
    // Register hardware keyboard listener for desktop / web keypresses
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    _recordActivity();
    return false; // Do not consume the event; allow it to propagate
  }

  /// Records activity throttled to at most once every 500ms to avoid overhead
  /// on rapid pointer movements.
  void _recordActivity() {
    final now = DateTime.now();
    if (now.difference(_lastThrottledRecord).inMilliseconds > 500) {
      _lastThrottledRecord = now;
      ref.read(sessionServiceProvider).recordActivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordActivity(),
      onPointerMove: (_) => _recordActivity(),
      onPointerHover: (_) => _recordActivity(),
      onPointerUp: (_) => _recordActivity(),
      onPointerSignal: (_) => _recordActivity(),
      child: widget.child,
    );
  }
}
