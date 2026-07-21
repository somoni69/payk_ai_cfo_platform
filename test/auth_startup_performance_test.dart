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
    test('accepts valid claims and maps known roles', () {
      final token = _jwt({'sub': 'farzod', 'role': 'admin', 'exp': 2000000000});

      final user = ApiAuthRepository.decodeUserFromToken(
        token,
        now: DateTime.utc(2026),
      );

      expect(user.username, 'farzod');
      expect(user.role, UserRole.director);
    });

    test('uses viewer instead of director for an unknown role', () {
      final token = _jwt({
        'sub': 'external-user',
        'role': 'custom-role',
        'exp': 2000000000,
      });

      final user = ApiAuthRepository.decodeUserFromToken(
        token,
        now: DateTime.utc(2026),
      );
      expect(user.role, UserRole.viewer);
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
      expect(biometrics.lastReason, contains('PAYK Ledger'));
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
    }
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
      'sub': 'queued-user',
      'role': 'accountant',
      'exp': 2000000000,
    });
    return ResponseBody.fromString(
      jsonEncode({'access_token': token}),
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

class _SessionRepository extends ApiAuthRepository {
  @override
  Future<AuthUser?> tryAutoLogin() async {
    return const AuthUser(username: 'user', role: UserRole.viewer);
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
