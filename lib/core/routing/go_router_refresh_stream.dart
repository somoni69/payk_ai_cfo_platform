import 'dart:async';

import 'package:flutter/material.dart';

/// Turns one or more streams (e.g. [AuthBloc], [PermissionsCubit]) into a
/// [Listenable] for [GoRouter.refreshListenable].
class GoRouterRefreshStream extends ChangeNotifier {
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscriptions.add(stream.listen((_) => notifyListeners()));
  }

  /// Notify when any of [streams] emits (auth + permissions refresh).
  GoRouterRefreshStream.merge(Iterable<Stream<dynamic>> streams) {
    for (final stream in streams) {
      _subscriptions.add(stream.listen((_) => notifyListeners()));
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
