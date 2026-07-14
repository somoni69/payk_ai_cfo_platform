import 'dart:async';
import 'package:flutter/material.dart';

/// Вспомогательный класс для превращения потока событий (например, состояния Блока)
/// в [Listenable], который используется в GoRouter для авто-перенаправлений.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
