import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/network/api_client.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_bloc.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_event.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_state.dart';
import 'package:payk_ai_cfo_platform/features/auth/data/api_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JWT session parsing', () {
    test('reads sub as id, role and name locally without /auth/me', () {
      final token = _jwt({
        'sub': 42,
        'role': 'director',
        'name': 'Фарзод Каримов',
        'exp': 2000000000,
      });

      final user = ApiAuthRepository.decodeUserFromToken(
        token,
        fallbackUsername: 'farzod',
        now: DateTime.utc(2026),
      );

      expect(user.id, 42);
      expect(user.name, 'Фарзод Каримов');
      expect(user.username, 'farzod');
      expect(user.displayName, 'Фарзод Каримов');
      expect(user.role, UserRole.director);
    });

    test('maps backend Role enum values and treats unknown as viewer', () {
      final director = ApiAuthRepository.decodeUserFromToken(
        _jwt({'sub': '7', 'role': 'admin', 'name': 'A', 'exp': 2000000000}),
        now: DateTime.utc(2026),
      );
      expect(director.id, 7);
      expect(director.role, UserRole.director);

      final unknown = ApiAuthRepository.decodeUserFromToken(
        _jwt({
          'sub': '8',
          'role': 'custom-role',
          'name': 'B',
          'exp': 2000000000,
        }),
        now: DateTime.utc(2026),
      );
      expect(unknown.role, UserRole.viewer);
    });

    test('rejects malformed, identity-less, expired, and timeless tokens', () {
      expect(
        () => ApiAuthRepository.decodeUserFromToken('not-a-jwt'),
        throwsFormatException,
      );
      expect(
        () => ApiAuthRepository.decodeUserFromToken(
          _jwt({'sub': 'user'}),
          now: DateTime.utc(2026),
        ),
        throwsFormatException,
      );
      expect(
        () => ApiAuthRepository.decodeUserFromToken(
          _jwt({'exp': 2000000000}),
          now: DateTime.utc(2026),
        ),
        throwsFormatException,
      );
      expect(
        () => ApiAuthRepository.decodeUserFromToken(
          _jwt({'sub': 'user', 'exp': 1}),
          now: DateTime.utc(2026),
        ),
        throwsFormatException,
      );
    });
  });

  test('long-running requests use the opt-in AI timeout policy', () {
    final options = ApiClient.longRunningOptions();
    expect(options.sendTimeout, const Duration(seconds: 30));
    expect(options.receiveTimeout, const Duration(seconds: 90));
  });

  test('request metadata is cached and concurrent 401s log out once', () async {
    FlutterSecureStorage.setMockInitialValues({
      'jwt_access_token': 'cached-token',
      'interface_language': 'tg',
    });
    final client = ApiClient();
    await client.bootstrap();

    final successAdapter = _RecordingAdapter(statusCode: 200);
    client.dio.httpClientAdapter = successAdapter;
    await client.dio.get<void>('/metadata-test');

    expect(
      successAdapter.lastOptions?.headers['Authorization'],
      'Bearer cached-token',
    );
    expect(successAdapter.lastOptions?.headers['Accept-Language'], 'tg');

    var unauthorizedCalls = 0;
    client.onUnauthorized = () => unauthorizedCalls++;
    client.dio.httpClientAdapter = _RecordingAdapter(statusCode: 401);

    await Future.wait<void>([
      client.dio.get<void>('/first').then<void>((_) {}, onError: (_) {}),
      client.dio.get<void>('/second').then<void>((_) {}, onError: (_) {}),
    ]);

    expect(unauthorizedCalls, 1);
    expect(await client.getAccessToken(), isNull);
    client.onUnauthorized = null;
  });

  test('disabled biometrics skips all biometric platform calls', () async {
    FlutterSecureStorage.setMockInitialValues({'use_biometrics': 'false'});
    final biometrics = _FakeBiometricAuthenticator();
    final bloc = AuthBloc(
      authRepository: _SessionRepository(),
      biometricAuthenticator: biometrics,
      storage: const FlutterSecureStorage(),
    );

    expect(bloc.state, isA<AuthInitial>());
    final authenticated = bloc.stream.firstWhere(
      (state) => state is AuthAuthenticated,
    );
    bloc.add(CheckAuthStatus());
    await authenticated;

    expect(biometrics.capabilityCalls, 0);
    expect(biometrics.authenticateCalls, 0);
    await bloc.close();
  });

  test(
    'enabled biometrics checks both capabilities and authenticates',
    () async {
      FlutterSecureStorage.setMockInitialValues({'use_biometrics': 'true'});
      ApiClient().cacheInterfaceLanguage('tg');
      final biometrics = _FakeBiometricAuthenticator();
      final bloc = AuthBloc(
        authRepository: _SessionRepository(),
        biometricAuthenticator: biometrics,
        storage: const FlutterSecureStorage(),
      );

      final authenticated = bloc.stream.firstWhere(
        (state) => state is AuthAuthenticated,
      );
      bloc.add(CheckAuthStatus());
      await authenticated;

      expect(biometrics.capabilityCalls, 2);
      expect(biometrics.authenticateCalls, 1);
      expect(biometrics.lastReason, contains('PAYK'));
      await bloc.close();
    },
  );

  test(
    'enabled biometric lock fails closed when biometrics are unavailable',
    () async {
      FlutterSecureStorage.setMockInitialValues({'use_biometrics': 'true'});
      final biometrics = _FakeBiometricAuthenticator(available: false);
      final bloc = AuthBloc(
        authRepository: _SessionRepository(),
        biometricAuthenticator: biometrics,
        storage: const FlutterSecureStorage(),
      );

      final unauthenticated = bloc.stream.firstWhere(
        (state) => state is AuthUnauthenticated,
      );
      bloc.add(CheckAuthStatus());
      await unauthenticated;

      expect(biometrics.capabilityCalls, 2);
      expect(biometrics.authenticateCalls, 0);
      await bloc.close();
    },
  );

  test('logout is committed after an in-flight login finishes', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = ApiClient();
    await client.clearAccessToken();
    await client.clearRefreshToken();
    final adapter = _ControlledLoginAdapter();
    client.dio.httpClientAdapter = adapter;
    final bloc = AuthBloc(
      authRepository: ApiAuthRepository(apiClient: client),
      biometricAuthenticator: _FakeBiometricAuthenticator(),
      storage: const FlutterSecureStorage(),
    );

    final authenticated = bloc.stream.firstWhere(
      (state) => state is AuthAuthenticated,
    );
    final unauthenticated = bloc.stream.firstWhere(
      (state) => state is AuthUnauthenticated,
    );

    try {
      bloc.add(
        const LoginSubmitted(username: 'queued-user', password: 'secret'),
      );
      await adapter.requestStarted.future;

      bloc.add(LogoutRequested());
      await Future<void>.delayed(Duration.zero);
      adapter.releaseResponse.complete();

      await authenticated;
      await unauthenticated;
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<AuthUnauthenticated>());
      expect(await client.getAccessToken(), isNull);
    } finally {
      if (!adapter.releaseResponse.isCompleted) {
        adapter.releaseResponse.complete();
      }
      await bloc.close();
      await client.clearAccessToken();
      await client.clearRefreshToken();
    }
  });

  test(
    'login persists both tokens without requiring rotation fields',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final client = ApiClient();
      await client.clearAccessToken();
      await client.clearRefreshToken();
      final access = _jwt({
        'sub': 11,
        'role': 'cashier',
        'name': 'Кассир Тест',
        'exp': 2000000000,
      });
      client.dio.httpClientAdapter = _JsonAdapter((options) {
        expect(options.path, contains('auth/login'));
        return {
          'two_factor_required': false,
          'challenge_id': null,
          'access_token': access,
          'refresh_token': 'refresh-stable',
          'token_type': 'bearer',
        };
      });

      final repo = ApiAuthRepository(apiClient: client);
      final result = await repo.login('cashier-1', 'secret');
      expect(result, isA<LoginSuccess>());
      final user = (result as LoginSuccess).user;
      expect(user.id, 11);
      expect(user.name, 'Кассир Тест');
      expect(user.username, 'cashier-1');
      expect(await client.getAccessToken(), access);
      expect(await client.getRefreshToken(), 'refresh-stable');
      await client.clearAccessToken();
      await client.clearRefreshToken();
    },
  );

  test('login returns 2FA challenge without storing tokens', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = ApiClient();
    await client.clearAccessToken();
    await client.clearRefreshToken();
    client.dio.httpClientAdapter = _JsonAdapter((options) {
      expect(options.path, '/auth/login');
      return {
        'two_factor_required': true,
        'challenge_id': 'chal-42',
        'access_token': null,
        'refresh_token': null,
        'token_type': 'bearer',
      };
    });

    final repo = ApiAuthRepository(apiClient: client);
    final result = await repo.login('user-2fa', 'secret');
    expect(result, isA<LoginTwoFactorRequired>());
    final challenge = result as LoginTwoFactorRequired;
    expect(challenge.challengeId, 'chal-42');
    expect(challenge.username, 'user-2fa');
    expect(await client.getAccessToken(), isNull);
    expect(await client.getRefreshToken(), isNull);
  });

  test('verify-2fa completes session and bloc authenticates', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = ApiClient();
    await client.clearAccessToken();
    await client.clearRefreshToken();
    final access = _jwt({
      'sub': 99,
      'role': 'manager',
      'name': 'Менеджер 2FA',
      'exp': 2000000000,
    });
    client.dio.httpClientAdapter = _JsonAdapter((options) {
      if (options.path.contains('auth/login')) {
        return {
          'two_factor_required': true,
          'challenge_id': 'chal-99',
          'access_token': null,
          'refresh_token': null,
        };
      }
      expect(options.path, contains('auth/verify-2fa'));
      // OpenAPI TokenPair: both tokens required after SMS verify.
      return {
        'access_token': access,
        'refresh_token': 'refresh-after-2fa',
        'token_type': 'bearer',
      };
    });

    final bloc = AuthBloc(
      authRepository: ApiAuthRepository(apiClient: client),
      biometricAuthenticator: _FakeBiometricAuthenticator(),
      storage: const FlutterSecureStorage(),
    );

    final twoFactor = bloc.stream.firstWhere(
      (state) => state is AuthTwoFactorRequired,
    );
    bloc.add(const LoginSubmitted(username: 'user-2fa', password: 'secret'));
    await twoFactor;
    expect(bloc.state, isA<AuthTwoFactorRequired>());

    final authenticated = bloc.stream.firstWhere(
      (state) => state is AuthAuthenticated,
    );
    bloc.add(const TwoFactorSubmitted(code: '123456'));
    await authenticated;

    expect(bloc.state, isA<AuthAuthenticated>());
    final authed = bloc.state as AuthAuthenticated;
    expect(authed.username, 'user-2fa');
    expect(authed.id, 99);
    expect(authed.displayName, 'Менеджер 2FA');
    expect(await client.getAccessToken(), access);
    expect(await client.getRefreshToken(), 'refresh-after-2fa');
    await bloc.close();
    await client.clearAccessToken();
    await client.clearRefreshToken();
  });

  test('refresh updates only access token (no rotation)', () async {
    final client = ApiClient();
    await client.bootstrap();
    final oldAccess = _jwt({
      'sub': 3,
      'role': 'viewer',
      'name': 'Old User',
      'exp': 2000000000,
    });
    final newAccess = _jwt({
      'sub': 3,
      'role': 'viewer',
      'name': 'Old User',
      'exp': 2100000000,
    });
    // Seed via API (singleton already bootstrapped earlier in this suite).
    await client.saveAccessToken(oldAccess);
    await client.saveRefreshToken('refresh-keep-me');
    client.dio.httpClientAdapter = _JsonAdapter((options) {
      expect(options.path, contains('auth/refresh'));
      // Backend may omit refresh_token entirely; even if present, client must ignore.
      return {
        'access_token': newAccess,
        'token_type': 'bearer',
        'refresh_token': 'should-not-be-stored',
      };
    });

    final repo = ApiAuthRepository(apiClient: client);
    final user = await repo.tryRefreshSession();
    expect(user, isNotNull);
    expect(user!.id, 3);
    expect(user.name, 'Old User');
    expect(await client.getAccessToken(), newAccess);
    expect(await client.getRefreshToken(), 'refresh-keep-me');
    await client.clearAccessToken();
    await client.clearRefreshToken();
  });

  test('fetchCurrentUser maps GET /auth/me UserRead fields', () async {
    final client = ApiClient();
    await client.bootstrap();
    await client.saveAccessToken(
      _jwt({'sub': 5, 'role': 'hr', 'name': 'JWT Name', 'exp': 2000000000}),
    );
    client.dio.httpClientAdapter = _JsonAdapter((options) {
      expect(options.path, contains('auth/me'));
      expect(options.method, 'GET');
      return {
        'id': 5,
        'username': 'hr.user',
        'full_name': 'HR Profile',
        'role': 'hr',
        'is_active': true,
        'two_factor_enabled': true,
        'created_at': '2026-01-01T00:00:00Z',
      };
    });

    final repo = ApiAuthRepository(apiClient: client);
    final profile = await repo.fetchCurrentUser();
    expect(profile.id, 5);
    expect(profile.username, 'hr.user');
    expect(profile.name, 'HR Profile');
    expect(profile.role, UserRole.hr);
    await client.clearAccessToken();
    await client.clearRefreshToken();
  });

  test('refresh 401 clears both tokens', () async {
    final client = ApiClient();
    await client.bootstrap();
    await client.saveAccessToken('stale-access');
    await client.saveRefreshToken('dead-refresh');
    client.dio.httpClientAdapter = _StatusAdapter(401, {
      'detail': 'Недействительный refresh-токен',
    });

    final repo = ApiAuthRepository(apiClient: client);
    final user = await repo.tryRefreshSession();
    expect(user, isNull);
    expect(await client.getAccessToken(), isNull);
    expect(await client.getRefreshToken(), isNull);
  });
}

String _jwt(Map<String, Object?> payload) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(json.encode(value))).replaceAll('=', '');

  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode(payload)}.'
      '${base64Url.encode([1, 2, 3]).replaceAll('=', '')}';
}

class _ControlledLoginAdapter implements HttpClientAdapter {
  final Completer<void> requestStarted = Completer<void>();
  final Completer<void> releaseResponse = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!requestStarted.isCompleted) requestStarted.complete();
    await releaseResponse.future;

    final token = _jwt({
      'sub': 1,
      'role': 'accountant',
      'name': 'Queued User',
      'exp': 2000000000,
    });
    return ResponseBody.fromString(
      jsonEncode({
        'two_factor_required': false,
        'access_token': token,
        'refresh_token': 'queued-refresh',
        'token_type': 'bearer',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RecordingAdapter implements HttpClientAdapter {
  final int statusCode;
  RequestOptions? lastOptions;

  _RecordingAdapter({required this.statusCode});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString('{}', statusCode);
  }

  @override
  void close({bool force = false}) {}
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this._build);

  final Map<String, dynamic> Function(RequestOptions options) _build;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(_build(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SessionRepository extends ApiAuthRepository {
  @override
  Future<AuthUser?> tryAutoLogin() async {
    return const AuthUser(
      id: 1,
      username: 'user',
      name: 'Test User',
      role: UserRole.viewer,
    );
  }
}

class _FakeBiometricAuthenticator implements BiometricAuthenticator {
  _FakeBiometricAuthenticator({this.available = true});

  final bool available;
  int capabilityCalls = 0;
  int authenticateCalls = 0;
  String? lastReason;

  @override
  Future<bool> canCheckBiometrics() async {
    capabilityCalls++;
    return available;
  }

  @override
  Future<bool> isDeviceSupported() async {
    capabilityCalls++;
    return available;
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCalls++;
    lastReason = reason;
    return available;
  }
}
