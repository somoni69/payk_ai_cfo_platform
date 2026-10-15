import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/network/user_facing_error.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_bloc.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_event.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_state.dart';
import 'package:payk_ai_cfo_platform/features/auth/data/api_auth_repository.dart';

class MockAuthRepository implements ApiAuthRepository {
  AuthUser? autoLoginUser;
  LoginResult? loginResult;
  LoginResult? verifyTwoFactorResult;
  AuthUser? refreshedUser;
  bool shouldThrowOnAutoLogin = false;
  bool shouldThrowOnLogin = false;
  bool shouldThrowOnVerifyTwoFactor = false;
  bool shouldThrowOnRefresh = false;
  int logoutCallCount = 0;
  String? lastLoginUsername;
  String? lastLoginPassword;
  int? lastLoginStoreId;

  @override
  Future<AuthUser?> tryAutoLogin() async {
    if (shouldThrowOnAutoLogin) throw Exception('AutoLogin network failure');
    return autoLoginUser;
  }

  @override
  Future<LoginResult> login(
    String username,
    String password, {
    int? storeId,
    bool asOwner = false,
  }) async {
    lastLoginUsername = username;
    lastLoginPassword = password;
    lastLoginStoreId = storeId;
    if (shouldThrowOnLogin) throw Exception('Неверный логин или пароль');
    return loginResult ??
        LoginSuccess(
          AuthUser(
            id: 1,
            username: username,
            name: 'Тестовый Пользователь',
            role: UserRole.director,
            storeId: storeId,
          ),
        );
  }

  @override
  Future<LoginResult> verifyTwoFactor({
    required String challengeId,
    required String code,
    required String username,
  }) async {
    if (shouldThrowOnVerifyTwoFactor) {
      throw Exception('Неверный код подтверждения');
    }
    return verifyTwoFactorResult ??
        LoginSuccess(
          AuthUser(
            id: 1,
            username: username,
            name: '2FA Пользователь',
            role: UserRole.director,
          ),
        );
  }

  @override
  Future<AuthUser?> tryRefreshSession() async {
    if (shouldThrowOnRefresh) return null;
    return refreshedUser;
  }

  @override
  Future<void> logout() async {
    logoutCallCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockBiometricAuthenticator implements BiometricAuthenticator {
  bool canCheck = true;
  bool isSupported = true;
  bool authResult = true;
  bool shouldThrow = false;
  String? lastReason;
  int authCallCount = 0;

  @override
  Future<bool> canCheckBiometrics() async => canCheck;

  @override
  Future<bool> isDeviceSupported() async => isSupported;

  @override
  Future<bool> authenticate({required String reason}) async {
    authCallCount++;
    lastReason = reason;
    if (shouldThrow) throw Exception('Biometrics hardware error');
    return authResult;
  }
}

class MockSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _storage = {};
  bool shouldThrow = false;

  MockSecureStorage() : super();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (shouldThrow) throw Exception('SecureStorage read failure');
    return _storage[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }
}

void main() {
  group('AuthBloc Comprehensive Unit Tests (R1-09)', () {
    late MockAuthRepository mockAuthRepository;
    late MockBiometricAuthenticator mockBiometrics;
    late MockSecureStorage mockStorage;
    late AuthBloc authBloc;

    final testUser = AuthUser(
      id: 42,
      username: 'farzod_cfo',
      name: 'Фарзод Главбух',
      role: UserRole.accountant,
      storeId: 10,
      storeName: 'Флагман Душанбе',
      accessTokenExpiresAt: DateTime.now().toUtc().add(
        const Duration(hours: 1),
      ),
    );

    setUp(() {
      mockAuthRepository = MockAuthRepository();
      mockBiometrics = MockBiometricAuthenticator();
      mockStorage = MockSecureStorage();
      authBloc = AuthBloc(
        authRepository: mockAuthRepository,
        biometricAuthenticator: mockBiometrics,
        storage: mockStorage,
      );
    });

    tearDown(() {
      authBloc.close();
    });

    test('Initial state is AuthInitial', () {
      expect(authBloc.state, isA<AuthInitial>());
    });

    group('CheckAuthStatus Event', () {
      test(
        'emits [AuthLoading, AuthUnauthenticated] when no active session exists',
        () async {
          mockAuthRepository.autoLoginUser = null;

          final expected = [isA<AuthLoading>(), isA<AuthUnauthenticated>()];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(CheckAuthStatus());
        },
      );

      test(
        'emits [AuthLoading, AuthUnauthenticated] when session exists and biometrics disabled (SEC-04)',
        () async {
          mockAuthRepository.autoLoginUser = testUser;
          await mockStorage.write(key: 'use_biometrics', value: 'false');

          final expected = [isA<AuthLoading>(), isA<AuthUnauthenticated>()];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(CheckAuthStatus());
        },
      );

      test(
        'emits [AuthLoading, AuthAuthenticated] when session exists, biometrics enabled and biometric auth succeeds',
        () async {
          mockAuthRepository.autoLoginUser = testUser;
          await mockStorage.write(key: 'use_biometrics', value: 'true');
          mockBiometrics.canCheck = true;
          mockBiometrics.isSupported = true;
          mockBiometrics.authResult = true;

          final expected = [
            isA<AuthLoading>(),
            isA<AuthAuthenticated>().having(
              (s) => s.username,
              'username',
              'farzod_cfo',
            ),
          ];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(CheckAuthStatus());

          await untilCalled(() => mockBiometrics.authCallCount > 0);
          expect(mockBiometrics.authCallCount, 1);
        },
      );

      test(
        'emits [AuthLoading, AuthUnauthenticated] when biometrics enabled but user cancels / fails',
        () async {
          mockAuthRepository.autoLoginUser = testUser;
          await mockStorage.write(key: 'use_biometrics', value: 'true');
          mockBiometrics.authResult = false;

          final expected = [isA<AuthLoading>(), isA<AuthUnauthenticated>()];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(CheckAuthStatus());
        },
      );

      test(
        'emits [AuthLoading, AuthUnauthenticated] when biometrics enabled but device not supported',
        () async {
          mockAuthRepository.autoLoginUser = testUser;
          await mockStorage.write(key: 'use_biometrics', value: 'true');
          mockBiometrics.isSupported = false;

          final expected = [isA<AuthLoading>(), isA<AuthUnauthenticated>()];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(CheckAuthStatus());
        },
      );

      test(
        'emits [AuthLoading, AuthUnauthenticated] when secure storage throws reading policy',
        () async {
          mockAuthRepository.autoLoginUser = testUser;
          mockStorage.shouldThrow = true;

          final expected = [isA<AuthLoading>(), isA<AuthUnauthenticated>()];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(CheckAuthStatus());
        },
      );
    });

    group('LoginSubmitted Event', () {
      test(
        'emits [AuthLoading, AuthAuthenticated] on valid credentials login',
        () async {
          mockAuthRepository.loginResult = LoginSuccess(testUser);

          final expected = [
            isA<AuthLoading>(),
            isA<AuthAuthenticated>()
                .having((s) => s.username, 'username', 'farzod_cfo')
                .having((s) => s.displayName, 'displayName', 'Фарзод Главбух'),
          ];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(
            const LoginSubmitted(
              username: '  farzod_cfo  ',
              password: 'super-secret-password',
              storeId: 10,
            ),
          );

          await untilCalled(() => mockAuthRepository.lastLoginUsername != null);
          expect(mockAuthRepository.lastLoginUsername, 'farzod_cfo');
          expect(mockAuthRepository.lastLoginPassword, 'super-secret-password');
          expect(mockAuthRepository.lastLoginStoreId, 10);
        },
      );

      test(
        'emits [AuthLoading, AuthTwoFactorRequired] when 2FA is required',
        () async {
          mockAuthRepository.loginResult = const LoginTwoFactorRequired(
            challengeId: 'challenge-xyz-987',
            username: 'farzod_cfo',
          );

          final expected = [
            isA<AuthLoading>(),
            isA<AuthTwoFactorRequired>()
                .having(
                  (s) => s.challengeId,
                  'challengeId',
                  'challenge-xyz-987',
                )
                .having((s) => s.username, 'username', 'farzod_cfo'),
          ];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(
            const LoginSubmitted(
              username: 'farzod_cfo',
              password: 'correct_password',
            ),
          );
        },
      );

      test(
        'emits [AuthLoading, AuthError] when login fails with exception',
        () async {
          mockAuthRepository.shouldThrowOnLogin = true;

          final expected = [
            isA<AuthLoading>(),
            isA<AuthError>().having(
              (s) => s.message,
              'message',
              ErrorKeys.loginFailed,
            ),
          ];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(
            const LoginSubmitted(
              username: 'wrong_user',
              password: 'wrong_password',
            ),
          );
        },
      );
    });

    group('TwoFactorSubmitted & TwoFactorCancelled Events', () {
      test(
        'verifies 2FA OTP code and emits [AuthLoading, AuthAuthenticated]',
        () async {
          mockAuthRepository.loginResult = const LoginTwoFactorRequired(
            challengeId: 'ch-123',
            username: 'farzod_cfo',
          );
          authBloc.add(
            const LoginSubmitted(username: 'farzod_cfo', password: 'pass'),
          );
          await authBloc.stream.firstWhere((s) => s is AuthTwoFactorRequired);

          mockAuthRepository.verifyTwoFactorResult = LoginSuccess(testUser);

          final expected = [
            isA<AuthLoading>(),
            isA<AuthAuthenticated>().having(
              (s) => s.username,
              'username',
              'farzod_cfo',
            ),
          ];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(const TwoFactorSubmitted(code: '  123456  '));
        },
      );

      test(
        'emits [AuthError, AuthTwoFactorRequired] when submitted OTP code is empty',
        () async {
          mockAuthRepository.loginResult = const LoginTwoFactorRequired(
            challengeId: 'ch-123',
            username: 'farzod_cfo',
          );
          authBloc.add(
            const LoginSubmitted(username: 'farzod_cfo', password: 'pass'),
          );
          await authBloc.stream.firstWhere((s) => s is AuthTwoFactorRequired);

          final expected = [
            isA<AuthError>().having(
              (s) => s.message,
              'message',
              ErrorKeys.twoFactorValidation,
            ),
            isA<AuthTwoFactorRequired>(),
          ];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(const TwoFactorSubmitted(code: '   '));
        },
      );

      test(
        'emits [AuthLoading, AuthError, AuthTwoFactorRequired] when 2FA verification fails',
        () async {
          mockAuthRepository.loginResult = const LoginTwoFactorRequired(
            challengeId: 'ch-123',
            username: 'farzod_cfo',
          );
          authBloc.add(
            const LoginSubmitted(username: 'farzod_cfo', password: 'pass'),
          );
          await authBloc.stream.firstWhere((s) => s is AuthTwoFactorRequired);

          mockAuthRepository.shouldThrowOnVerifyTwoFactor = true;

          final expected = [
            isA<AuthLoading>(),
            isA<AuthError>().having(
              (s) => s.message,
              'message',
              ErrorKeys.twoFactorFailed,
            ),
            isA<AuthTwoFactorRequired>(),
          ];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(const TwoFactorSubmitted(code: '999999'));
        },
      );

      test(
        'emits [AuthError] when TwoFactorSubmitted without active challenge',
        () async {
          final expected = [
            isA<AuthError>().having(
              (s) => s.message,
              'message',
              ErrorKeys.twoFactorFailed,
            ),
          ];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(const TwoFactorSubmitted(code: '123456'));
        },
      );

      test('TwoFactorCancelled emits [AuthUnauthenticated]', () async {
        mockAuthRepository.loginResult = const LoginTwoFactorRequired(
          challengeId: 'ch-123',
          username: 'farzod_cfo',
        );
        authBloc.add(
          const LoginSubmitted(username: 'farzod_cfo', password: 'pass'),
        );
        await authBloc.stream.firstWhere((s) => s is AuthTwoFactorRequired);

        final expected = [isA<AuthUnauthenticated>()];

        expectLater(authBloc.stream, emitsInOrder(expected));
        authBloc.add(const TwoFactorCancelled());
      });
    });

    group('BiometricLoginRequested Event', () {
      test(
        'emits [AuthLoading, AuthAuthenticated] on successful biometric login',
        () async {
          mockAuthRepository.autoLoginUser = testUser;
          mockBiometrics.canCheck = true;
          mockBiometrics.isSupported = true;
          mockBiometrics.authResult = true;

          final expected = [
            isA<AuthLoading>(),
            isA<AuthAuthenticated>().having(
              (s) => s.username,
              'username',
              'farzod_cfo',
            ),
          ];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(BiometricLoginRequested());
        },
      );

      test(
        'emits [AuthLoading, AuthError] when biometrics unavailable',
        () async {
          mockBiometrics.canCheck = false;

          final expected = [
            isA<AuthLoading>(),
            isA<AuthError>().having(
              (s) => s.message,
              'message',
              ErrorKeys.biometricsUnavailable,
            ),
          ];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(BiometricLoginRequested());
        },
      );

      test(
        'emits [AuthLoading, AuthError] when no session found for biometric login',
        () async {
          mockBiometrics.canCheck = true;
          mockBiometrics.isSupported = true;
          mockAuthRepository.autoLoginUser = null;

          final expected = [
            isA<AuthLoading>(),
            isA<AuthError>().having(
              (s) => s.message,
              'message',
              ErrorKeys.biometricsNoSession,
            ),
          ];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(BiometricLoginRequested());
        },
      );

      test(
        'emits [AuthLoading, AuthError] when biometric prompt rejected',
        () async {
          mockAuthRepository.autoLoginUser = testUser;
          mockBiometrics.canCheck = true;
          mockBiometrics.isSupported = true;
          mockBiometrics.authResult = false;

          final expected = [
            isA<AuthLoading>(),
            isA<AuthError>().having(
              (s) => s.message,
              'message',
              ErrorKeys.biometricsFailed,
            ),
          ];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(BiometricLoginRequested());
        },
      );
    });

    group('SessionSoftExpiryReached Event', () {
      test('refreshes session and emits updated [AuthAuthenticated]', () async {
        mockAuthRepository.loginResult = LoginSuccess(testUser);
        authBloc.add(
          const LoginSubmitted(username: 'farzod_cfo', password: 'pwd'),
        );
        await authBloc.stream.firstWhere((s) => s is AuthAuthenticated);

        final updatedExpiry = DateTime.now().toUtc().add(
          const Duration(hours: 2),
        );
        final refreshedUser = testUser.copyWith(
          name: 'Фарзод Обновленный',
          accessTokenExpiresAt: updatedExpiry,
        );
        mockAuthRepository.refreshedUser = refreshedUser;

        final expected = [
          isA<AuthAuthenticated>()
              .having((s) => s.name, 'name', 'Фарзод Обновленный')
              .having((s) => s.accessTokenExpiresAt, 'expiry', updatedExpiry),
        ];

        expectLater(authBloc.stream, emitsInOrder(expected));
        authBloc.add(const SessionSoftExpiryReached());
      });

      test(
        'logs out and emits [AuthError, AuthUnauthenticated] on refresh failure',
        () async {
          mockAuthRepository.loginResult = LoginSuccess(testUser);
          authBloc.add(
            const LoginSubmitted(username: 'farzod_cfo', password: 'pwd'),
          );
          await authBloc.stream.firstWhere((s) => s is AuthAuthenticated);

          mockAuthRepository.refreshedUser = null;
          mockAuthRepository.shouldThrowOnRefresh = true;

          final expected = [
            isA<AuthError>().having(
              (s) => s.message,
              'message',
              ErrorKeys.sessionExpired,
            ),
            isA<AuthUnauthenticated>(),
          ];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(const SessionSoftExpiryReached());

          await untilCalled(() => mockAuthRepository.logoutCallCount > 0);
          expect(mockAuthRepository.logoutCallCount, 1);
        },
      );
    });

    group('ActingStoreUpdated & LogoutRequested Events', () {
      test(
        'ActingStoreUpdated updates storeId and storeName in AuthAuthenticated state',
        () async {
          mockAuthRepository.loginResult = LoginSuccess(testUser);
          authBloc.add(
            const LoginSubmitted(username: 'farzod_cfo', password: 'pwd'),
          );
          await authBloc.stream.firstWhere((s) => s is AuthAuthenticated);

          final expected = [
            isA<AuthAuthenticated>()
                .having((s) => s.storeId, 'storeId', 99)
                .having((s) => s.storeName, 'storeName', 'Филиал Худжанд'),
          ];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(
            const ActingStoreUpdated(storeId: 99, storeName: 'Филиал Худжанд'),
          );
        },
      );

      test('ActingStoreUpdated with null storeId clears store', () async {
        mockAuthRepository.loginResult = LoginSuccess(testUser);
        authBloc.add(
          const LoginSubmitted(username: 'farzod_cfo', password: 'pwd'),
        );
        await authBloc.stream.firstWhere((s) => s is AuthAuthenticated);

        final expected = [
          isA<AuthAuthenticated>()
              .having((s) => s.storeId, 'storeId', isNull)
              .having((s) => s.storeName, 'storeName', isNull),
        ];

        expectLater(authBloc.stream, emitsInOrder(expected));
        authBloc.add(const ActingStoreUpdated(storeId: null, storeName: null));
      });

      test(
        'LogoutRequested emits [AuthLoading, AuthUnauthenticated] and calls repository logout',
        () async {
          mockAuthRepository.loginResult = LoginSuccess(testUser);
          authBloc.add(
            const LoginSubmitted(username: 'farzod_cfo', password: 'pwd'),
          );
          await authBloc.stream.firstWhere((s) => s is AuthAuthenticated);

          final expected = [isA<AuthLoading>(), isA<AuthUnauthenticated>()];

          expectLater(authBloc.stream, emitsInOrder(expected));
          authBloc.add(LogoutRequested());

          await untilCalled(() => mockAuthRepository.logoutCallCount > 0);
          expect(mockAuthRepository.logoutCallCount, 1);
        },
      );
    });

    group('Security & State Hygiene', () {
      test('LoginSubmitted does not expose password in Equatable props', () {
        const event1 = LoginSubmitted(
          username: 'user1',
          password: 'secret-password-1',
        );
        const event2 = LoginSubmitted(
          username: 'user1',
          password: 'secret-password-2',
        );
        expect(event1.props, contains('user1'));
        expect(event1.props, isNot(contains('secret-password-1')));
        expect(event1, equals(event2)); // props match regardless of password
      });

      test('TwoFactorSubmitted props are empty to avoid leaking OTP codes', () {
        const event = TwoFactorSubmitted(code: '654321');
        expect(event.props, isEmpty);
      });

      test(
        'AuthAuthenticated displayName precedence: name -> username -> id',
        () {
          const userWithName = AuthAuthenticated(
            id: 10,
            username: 'user_login',
            name: 'Иван Иванов',
            role: UserRole.cashier,
          );
          expect(userWithName.displayName, 'Иван Иванов');

          const userWithUsername = AuthAuthenticated(
            id: 10,
            username: 'user_login',
            name: '  ',
            role: UserRole.cashier,
          );
          expect(userWithUsername.displayName, 'user_login');

          const userWithIdOnly = AuthAuthenticated(
            id: 10,
            username: '  ',
            name: '',
            role: UserRole.cashier,
          );
          expect(userWithIdOnly.displayName, '#10');
        },
      );
    });
  });
}

Future<void> untilCalled(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
