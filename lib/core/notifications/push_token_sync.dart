import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/notifications/domain/notifications_repository.dart';
import '../observability/app_error_reporter.dart';

/// Synchronizes this device's FCM token with `PUT/DELETE /api/notifications/fcm-token`.
///
/// Handles startup ordering between Firebase token delivery and login, shared
/// tablet account switches (same FCM token, different employee), retry on app
/// resume after transient errors, and pre-logout removal while the JWT is valid.
class PushTokenSync {
  PushTokenSync({
    required this._repository,
    required this._tokenProvider,
    this._hasAuthToken,
    String? Function()? platformProvider,
    this._unregisterTimeout = const Duration(seconds: 5),
  }) : _platformProvider = platformProvider ?? defaultPlatformName;

  final NotificationsRepository _repository;
  final Future<String?> Function() _tokenProvider;
  final Future<bool> Function()? _hasAuthToken;
  final String? Function() _platformProvider;
  final Duration _unregisterTimeout;

  String? _activeUserKey;
  String? _lastSyncedUserKey;
  String? _lastSyncedToken;
  String? _inFlightUserKey;
  String? _inFlightToken;
  Future<void>? _inFlightSync;

  static String? defaultPlatformName() {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }

  /// Registers the current device token for [userKey] when authenticated.
  Future<void> onAuthenticated(String userKey) {
    final normalized = userKey.trim();
    if (normalized.isEmpty) return Future<void>.value();
    _activeUserKey = normalized;
    return _sync(userKey: normalized);
  }

  /// Registers a newly delivered or refreshed FCM [token] if logged in.
  Future<void> onTokenUpdate(String token) {
    final normalized = token.trim();
    final userKey = _activeUserKey;
    if (normalized.isEmpty || userKey == null) {
      return Future<void>.value();
    }
    return _sync(userKey: userKey, explicitToken: normalized);
  }

  /// Retries registration (e.g. on resume) if the active user is not yet synced.
  Future<void> retryIfNeeded() {
    final userKey = _activeUserKey;
    if (userKey == null) return Future<void>.value();
    return _sync(userKey: userKey);
  }

  /// Clears local sync state when the app has no authenticated session.
  void onSignedOut() {
    _activeUserKey = null;
    _lastSyncedUserKey = null;
    _lastSyncedToken = null;
  }

  /// Unregisters this device's FCM token **before** JWT credentials are wiped.
  Future<void> unregisterBeforeLogout() async {
    final previousSyncedToken = _lastSyncedToken;
    _activeUserKey = null;
    _lastSyncedUserKey = null;
    _lastSyncedToken = null;

    // Wait briefly for any in-flight PUT so it cannot re-register after DELETE.
    final inFlight = _inFlightSync;
    if (inFlight != null) {
      try {
        await inFlight.timeout(const Duration(seconds: 2));
      } catch (_) {
        // Proceed with DELETE regardless of PUT timeout or failure.
      }
    }

    if (_hasAuthToken != null) {
      try {
        if (!await _hasAuthToken()) return;
      } catch (_) {
        return;
      }
    }

    final tokens = <String>{};
    try {
      final current = (await _tokenProvider())?.trim();
      if (current != null && current.isNotEmpty) {
        tokens.add(current);
      }
    } catch (_) {
      // Fall back to the last synced token if Firebase is temporarily unavailable.
    }
    if (previousSyncedToken != null && previousSyncedToken.isNotEmpty) {
      tokens.add(previousSyncedToken);
    }

    for (final token in tokens) {
      try {
        await _repository.unregisterFcmToken(token).timeout(_unregisterTimeout);
      } catch (e, st) {
        // Logout must always complete even offline; backend PUT also reassigns
        // the token when another employee signs in on the same device.
        AppErrorReporter.reportOptional(
          e,
          st,
          context: 'push_token_unregister',
        );
      }
    }
  }

  Future<void> _sync({required String userKey, String? explicitToken}) async {
    String? token = explicitToken?.trim();
    if (token == null || token.isEmpty) {
      try {
        token = (await _tokenProvider())?.trim();
      } catch (_) {
        return;
      }
    }
    if (token == null || token.isEmpty) return;
    if (_activeUserKey != userKey) return;
    if (_lastSyncedUserKey == userKey && _lastSyncedToken == token) return;

    if (_inFlightSync != null) {
      if (_inFlightUserKey == userKey && _inFlightToken == token) {
        return _inFlightSync!;
      }
      try {
        await _inFlightSync;
      } catch (_) {}
      if (_activeUserKey != userKey) return;
      if (_lastSyncedUserKey == userKey && _lastSyncedToken == token) return;
    }

    final platform = _platformProvider();
    _inFlightUserKey = userKey;
    _inFlightToken = token;

    late final Future<void> task;
    task = _performRegister(userKey: userKey, token: token, platform: platform)
        .whenComplete(() {
          if (identical(_inFlightSync, task)) {
            _inFlightSync = null;
            _inFlightUserKey = null;
            _inFlightToken = null;
          }
        });
    _inFlightSync = task;
    return task;
  }

  Future<void> _performRegister({
    required String userKey,
    required String token,
    required String? platform,
  }) async {
    try {
      await _repository.registerFcmToken(token, platform: platform);
      if (_activeUserKey == userKey) {
        _lastSyncedUserKey = userKey;
        _lastSyncedToken = token;
      }
    } catch (e, st) {
      AppErrorReporter.reportOptional(e, st, context: 'push_token_register');
    }
  }
}
