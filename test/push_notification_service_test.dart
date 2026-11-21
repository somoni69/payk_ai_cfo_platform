import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:payk_ai_cfo_platform/core/notifications/push_notification_service.dart';
import 'package:payk_ai_cfo_platform/core/notifications/push_token_sync.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_bloc.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_event.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_state.dart';
import 'package:payk_ai_cfo_platform/features/auth/domain/auth_repository.dart';
import 'package:payk_ai_cfo_platform/features/network/domain/network_repository.dart';
import 'package:payk_ai_cfo_platform/features/notifications/data/api_notifications_repository.dart';
import 'package:payk_ai_cfo_platform/features/notifications/domain/notification_model.dart';
import 'package:payk_ai_cfo_platform/features/notifications/domain/notifications_repository.dart';
import 'package:payk_ai_cfo_platform/firebase_options.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'ok': true, 'devices': 1}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakePushRepository implements NotificationsRepository {
  final List<({String token, String? platform})> registered = [];
  final List<String> unregistered = [];
  final List<String> events = [];
  bool failRegister = false;
  bool failUnregister = false;
  Completer<void>? registerStarted;
  Completer<void>? registerGate;

  @override
  Future<List<AppNotification>> getNotifications() async => const [];

  @override
  Future<List<AppNotification>> refreshNotifications() async => const [];

  @override
  Future<void> markAsRead(String id) async {}

  @override
  Future<List<AppNotification>> getInbox({int limit = 30}) async => const [];

  @override
  Future<int> getUnreadCount() async => 0;

  @override
  Future<void> markAllRead() async {}

  @override
  Future<void> registerFcmToken(String token, {String? platform}) async {
    events.add('register:$token');
    if (registerStarted != null && !registerStarted!.isCompleted) {
      registerStarted!.complete();
    }
    final gate = registerGate;
    if (gate != null) await gate.future;
    if (failRegister) throw Exception('temporary network error');
    registered.add((token: token, platform: platform));
  }

  @override
  Future<void> unregisterFcmToken(String token) async {
    events.add('unregister:$token');
    if (failUnregister) throw Exception('offline during logout');
    unregistered.add(token);
  }
}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockNetworkRepository extends Mock implements NetworkRepository {}

void main() {
  group('DefaultFirebaseOptions (Payk Business)', () {
    test('uses shared payk-app-loyalty project with tj.payk.cfo appId', () {
      expect(DefaultFirebaseOptions.android.projectId, 'payk-app-loyalty');
      expect(DefaultFirebaseOptions.android.messagingSenderId, '713617302599');
      expect(
        DefaultFirebaseOptions.android.appId,
        '1:713617302599:android:550d18f5a92828d306bd62',
      );
      expect(
        DefaultFirebaseOptions.android.storageBucket,
        'payk-app-loyalty.firebasestorage.app',
      );
    });

    test('currentPlatform resolves Android and Payk Business iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        DefaultFirebaseOptions.currentPlatform.appId,
        DefaultFirebaseOptions.android.appId,
      );
      expect(DefaultFirebaseOptions.isSupportedPlatform, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(DefaultFirebaseOptions.isSupportedPlatform, isTrue);
      expect(
        DefaultFirebaseOptions.currentPlatform.appId,
        '1:713617302599:ios:858a3617f8f1fd0906bd62',
      );
      expect(
        DefaultFirebaseOptions.currentPlatform.iosBundleId,
        'tj.payk.cfo.app',
      );

      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('PushNotificationService', () {
    test('uses business-isolated topic and normalizes routes safely', () {
      expect(PushNotificationService.defaultTopic, 'business_all');
      expect(PushNotificationService.defaultRoute, '/inbox');
      expect(PushNotificationService.normalizeRoute(null), '/inbox');
      expect(PushNotificationService.normalizeRoute(''), '/inbox');
      expect(PushNotificationService.normalizeRoute('notifications'), '/inbox');
      expect(
        PushNotificationService.normalizeRoute(' /notifications '),
        '/notifications',
      );
      expect(PushNotificationService.normalizeRoute('/tasks'), '/tasks');
    });
  });

  group('ApiNotificationsRepository FCM token endpoints', () {
    test(
      'PUT /notifications/fcm-token sends trimmed token and platform',
      () async {
        final adapter = _RecordingAdapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
          ..httpClientAdapter = adapter;
        final repository = ApiNotificationsRepository(dio: dio);

        await repository.registerFcmToken('  fcm_tok_1  ', platform: 'android');
        await repository.registerFcmToken('fcm_tok_2');
        await repository.registerFcmToken('   ');

        expect(adapter.requests, hasLength(2));

        expect(adapter.requests[0].method, 'PUT');
        expect(adapter.requests[0].path, '/notifications/fcm-token');
        expect(adapter.requests[0].data, {
          'fcm_token': 'fcm_tok_1',
          'platform': 'android',
        });

        expect(adapter.requests[1].method, 'PUT');
        expect(adapter.requests[1].path, '/notifications/fcm-token');
        expect(adapter.requests[1].data, {'fcm_token': 'fcm_tok_2'});
      },
    );

    test(
      'DELETE /notifications/fcm-token sends token and skips 401 handler',
      () async {
        final adapter = _RecordingAdapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
          ..httpClientAdapter = adapter;
        final repository = ApiNotificationsRepository(dio: dio);

        await repository.unregisterFcmToken(' fcm_tok_1 ');
        await repository.unregisterFcmToken('');

        expect(adapter.requests, hasLength(1));
        expect(adapter.requests[0].method, 'DELETE');
        expect(adapter.requests[0].path, '/notifications/fcm-token');
        expect(adapter.requests[0].data, {'fcm_token': 'fcm_tok_1'});
        expect(adapter.requests[0].extra['skipUnauthorizedHandler'], isTrue);
      },
    );
  });

  group('PushTokenSync', () {
    test('waits for authentication before registering cached token', () async {
      final repo = _FakePushRepository();
      String? token = 'tok_initial';
      final sync = PushTokenSync(
        repository: repo,
        tokenProvider: () async => token,
        platformProvider: () => 'android',
      );

      await sync.onTokenUpdate('tok_initial');
      expect(repo.registered, isEmpty);

      await sync.onAuthenticated('42');
      expect(repo.registered, [(token: 'tok_initial', platform: 'android')]);

      // Repeated auth events for the same user/token do not re-register.
      await sync.onAuthenticated('42');
      expect(repo.registered, hasLength(1));
    });

    test(
      'registers when token arrives after authentication and on refresh',
      () async {
        final repo = _FakePushRepository();
        String? token;
        final sync = PushTokenSync(
          repository: repo,
          tokenProvider: () async => token,
          platformProvider: () => 'ios',
        );

        await sync.onAuthenticated('42');
        expect(repo.registered, isEmpty);

        token = 'tok_v1';
        await sync.onTokenUpdate('tok_v1');
        token = 'tok_v2';
        await sync.onTokenUpdate('tok_v2');

        expect(repo.registered, [
          (token: 'tok_v1', platform: 'ios'),
          (token: 'tok_v2', platform: 'ios'),
        ]);
      },
    );

    test(
      're-registers same token after account switch on shared device',
      () async {
        final repo = _FakePushRepository();
        var hasJwt = true;
        final sync = PushTokenSync(
          repository: repo,
          tokenProvider: () async => 'shared_tablet_token',
          hasAuthToken: () async => hasJwt,
          platformProvider: () => 'android',
        );

        await sync.onAuthenticated('cashier_1');
        expect(repo.registered, hasLength(1));

        await sync.unregisterBeforeLogout();
        expect(repo.unregistered, ['shared_tablet_token']);

        await sync.onAuthenticated('cashier_2');
        expect(repo.registered, hasLength(2));
        expect(repo.registered.last.token, 'shared_tablet_token');
      },
    );

    test('retries registration on resume after transient failure', () async {
      final repo = _FakePushRepository()..failRegister = true;
      final sync = PushTokenSync(
        repository: repo,
        tokenProvider: () async => 'tok_retry',
        platformProvider: () => 'android',
      );

      await sync.onAuthenticated('7');
      expect(repo.registered, isEmpty);

      repo.failRegister = false;
      await sync.retryIfNeeded();
      expect(repo.registered, [(token: 'tok_retry', platform: 'android')]);
    });

    test(
      'skips DELETE when JWT is already gone and waits for in-flight PUT first',
      () async {
        final repo = _FakePushRepository();
        final started = Completer<void>();
        final gate = Completer<void>();
        repo
          ..registerStarted = started
          ..registerGate = gate;

        final sync = PushTokenSync(
          repository: repo,
          tokenProvider: () async => 'tok_race',
          hasAuthToken: () async => true,
          platformProvider: () => 'android',
        );

        final putFuture = sync.onAuthenticated('10');
        await started.future;
        final logoutFuture = sync.unregisterBeforeLogout();

        // Release PUT; DELETE must run strictly after PUT completes.
        gate.complete();
        await Future.wait([putFuture, logoutFuture]);

        expect(repo.events, ['register:tok_race', 'unregister:tok_race']);

        // When JWT is already cleared (401 forced logout), DELETE is skipped.
        final noJwtRepo = _FakePushRepository();
        final noJwtSync = PushTokenSync(
          repository: noJwtRepo,
          tokenProvider: () async => 'tok_expired',
          hasAuthToken: () async => false,
        );
        await noJwtSync.unregisterBeforeLogout();
        expect(noJwtRepo.unregistered, isEmpty);
      },
    );
  });

  group('AuthBloc logout push cleanup', () {
    test(
      'runs onBeforeLogout strictly before authRepository.logout()',
      () async {
        final authRepo = _MockAuthRepository();
        final networkRepo = _MockNetworkRepository();
        final order = <String>[];

        when(() => authRepo.logout()).thenAnswer((_) async {
          order.add('auth_logout');
        });
        when(() => networkRepo.clearActingStore()).thenAnswer((_) async {});

        final bloc = AuthBloc(
          authRepository: authRepo,
          networkRepository: networkRepo,
          onBeforeLogout: () async {
            order.add('delete_fcm_token');
          },
        );

        final done = expectLater(
          bloc.stream,
          emitsInOrder([isA<AuthLoading>(), isA<AuthUnauthenticated>()]),
        );
        bloc.add(LogoutRequested());
        await done;
        await bloc.close();

        expect(order, ['delete_fcm_token', 'auth_logout']);
      },
    );

    test('completes logout even when onBeforeLogout throws', () async {
      final authRepo = _MockAuthRepository();
      final networkRepo = _MockNetworkRepository();

      when(() => authRepo.logout()).thenAnswer((_) async {});
      when(() => networkRepo.clearActingStore()).thenAnswer((_) async {});

      final bloc = AuthBloc(
        authRepository: authRepo,
        networkRepository: networkRepo,
        onBeforeLogout: () async => throw Exception('offline'),
      );

      final done = expectLater(
        bloc.stream,
        emitsInOrder([isA<AuthLoading>(), isA<AuthUnauthenticated>()]),
      );
      bloc.add(LogoutRequested());
      await done;
      await bloc.close();

      verify(() => authRepo.logout()).called(1);
    });
  });
}
