import 'dart:async';

import 'package:flutter/widgets.dart';

/// Periodic work that stops while the app is in background.
///
/// On return to foreground [onTick] runs at once (fresh data or clock), then
/// the period starts again. Call [dispose] from the owner's `dispose`.
class ForegroundTicker with WidgetsBindingObserver {
  ForegroundTicker(this.interval, this.onTick) {
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  final Duration interval;
  final VoidCallback onTick;
  Timer? _timer;
  bool _disposed = false;

  bool get isActive => _timer?.isActive ?? false;

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => onTick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (_timer != null) return;
        onTick();
        _start();
      case AppLifecycleState.paused ||
          AppLifecycleState.hidden ||
          AppLifecycleState.detached:
        _timer?.cancel();
        _timer = null;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }
}
