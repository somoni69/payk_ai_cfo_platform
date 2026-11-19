import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

/// Top-level background handler for FCM messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty && DefaultFirebaseOptions.isSupportedPlatform) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}
  _log('[PushNotificationService] Background message: ${message.messageId}');
}

/// Manages Firebase Cloud Messaging and local foreground notifications for Payk Business.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const String defaultRoute = '/inbox';
  static const String defaultTopic = 'business_all';
  static const Color _notificationColor = Color(0xFF362CD1);

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
        'payk_business_notifications',
        'Payk Business Уведомления',
        description:
            'Операционные уведомления, задачи и предупреждения Payk Business',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _fcmToken;
  void Function(String route)? _onNotificationTap;
  Future<void> Function(String token)? _onTokenUpdate;
  VoidCallback? _onForegroundMessage;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  StreamSubscription<String>? _tokenRefreshSub;

  String? get fcmToken => _fcmToken;

  /// Initializes Firebase, notification channels, permissions, and tap handlers.
  Future<void> initialize({
    void Function(String route)? onNotificationTap,
    Future<void> Function(String token)? onTokenUpdate,
    VoidCallback? onForegroundMessage,
  }) async {
    _onNotificationTap = onNotificationTap ?? _onNotificationTap;
    _onTokenUpdate = onTokenUpdate ?? _onTokenUpdate;
    _onForegroundMessage = onForegroundMessage ?? _onForegroundMessage;
    if (_isInitialized || !DefaultFirebaseOptions.isSupportedPlatform) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      _log('[PushNotificationService] Firebase init skipped: $e');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _requestPermissions();
      await _setupLocalNotifications();
      _listenForegroundMessages();
      await _setupInteractedMessage();
      await _setupTokenAndTopics();
      _isInitialized = true;
      _log('[PushNotificationService] Initialized successfully');
    } catch (e) {
      _log('[PushNotificationService] Setup skipped or failed: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    _log(
      '[PushNotificationService] Authorization status: ${settings.authorizationStatus}',
    );

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        _onNotificationTap?.call(normalizeRoute(response.payload));
      },
    );

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.createNotificationChannel(_defaultChannel);
  }

  void _listenForegroundMessages() {
    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      _log('[PushNotificationService] Foreground message: ${message.data}');
      _onForegroundMessage?.call();

      final notification = message.notification;
      final title = notification?.title ?? _stringData(message.data['title']);
      final body = notification?.body ?? _stringData(message.data['body']);
      final route = normalizeRoute(_stringData(message.data['route']));

      final shouldShowLocal =
          (title != null || body != null) &&
          (defaultTargetPlatform == TargetPlatform.android ||
              notification == null);

      if (shouldShowLocal) {
        _localNotifications.show(
          id:
              message.messageId?.hashCode ??
              notification?.hashCode ??
              message.hashCode,
          title: title ?? 'Payk Business',
          body: body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _defaultChannel.id,
              _defaultChannel.name,
              channelDescription: _defaultChannel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@drawable/ic_notification',
              color: _notificationColor,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: route,
        );
      }
    });
  }

  Future<void> _setupInteractedMessage() async {
    var handledInitial = false;

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      handledInitial = true;
      _handleMessageClick(initialMessage);
    }

    if (!handledInitial) {
      try {
        final launchDetails = await _localNotifications
            .getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp == true) {
          final payload = launchDetails?.notificationResponse?.payload;
          _onNotificationTap?.call(normalizeRoute(payload));
        }
      } catch (e) {
        _log('[PushNotificationService] Launch details error: $e');
      }
    }

    _openedAppSub?.cancel();
    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleMessageClick,
    );
  }

  void _handleMessageClick(RemoteMessage message) {
    _log('[PushNotificationService] Notification opened: ${message.data}');
    final route = normalizeRoute(_stringData(message.data['route']));
    _onNotificationTap?.call(route);
  }

  static String normalizeRoute(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty || !trimmed.startsWith('/')) {
      return defaultRoute;
    }
    return trimmed;
  }

  String? _stringData(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _setupTokenAndTopics() async {
    Future<void> publish(String? token) async {
      if (token == null || token.isEmpty) return;
      _fcmToken = token;
      _log('[PushNotificationService] FCM token ready (${token.length})');
      await _onTokenUpdate?.call(token);
      // APNs registration can finish after the first topic subscription attempt.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          await _fcm.subscribeToTopic(defaultTopic);
        } catch (e) {
          _log('[PushNotificationService] Subscribe to topic error: $e');
        }
      }
    }

    _tokenRefreshSub?.cancel();
    // FCM HTTP v1 sends to registration tokens; onRegistered emits only the FID.
    // ignore: deprecated_member_use
    _tokenRefreshSub = _fcm.onTokenRefresh.listen(publish);

    try {
      // ignore: deprecated_member_use
      await publish(await _fcm.getToken());
    } catch (e) {
      _log('[PushNotificationService] Error reading FCM token: $e');
    }

    try {
      await _fcm.subscribeToTopic(defaultTopic);
      _log('[PushNotificationService] Subscribed to topic "$defaultTopic"');
    } catch (e) {
      _log('[PushNotificationService] Subscribe to topic error: $e');
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
    } catch (e) {
      _log('[PushNotificationService] Failed to subscribe to $topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
    } catch (e) {
      _log('[PushNotificationService] Failed to unsubscribe from $topic: $e');
    }
  }
}
