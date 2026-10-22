import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_bloc.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_event.dart';
import 'package:payk_ai_cfo_platform/features/auth/bloc/auth_state.dart';
import 'package:payk_ai_cfo_platform/features/auth/data/api_auth_repository.dart';

class E2EAuthRepository implements ApiAuthRepository {
  AuthUser? currentUser;
  AuthUser? autoLoginSession;
  bool shouldFailRefresh = false;
  int refreshCount = 0;
  int logoutCount = 0;

  @override
  Future<LoginResult> login(
    String username,
    String password, {
    int? storeId,
    bool asOwner = false,
  }) async {
    final user = AuthUser(
      id: 100,
      username: username,
      name: 'Фарзод Директор',
      role: UserRole.director,
      storeId: storeId,
      accessTokenExpiresAt: DateTime.now().toUtc().add(
        const Duration(minutes: 15),
      ),
    );
    currentUser = user;
    autoLoginSession = user;
    return LoginSuccess(user);
  }

  @override
  Future<bool> hasStoredSession() async =>
      autoLoginSession != null || currentUser != null;

  @override
  Future<AuthUser?> tryAutoLogin() async => autoLoginSession;

  @override
  Future<AuthUser?> tryRefreshSession() async {
    refreshCount++;
    if (shouldFailRefresh) {
      currentUser = null;
      autoLoginSession = null;
      return null;
    }
    final refreshed = currentUser?.copyWith(
      accessTokenExpiresAt: DateTime.now().toUtc().add(
        const Duration(minutes: 30),
      ),
    );
    currentUser = refreshed;
    autoLoginSession = refreshed;
    return refreshed;
  }

  @override
  Future<void> logout() async {
    logoutCount++;
    currentUser = null;
    autoLoginSession = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class E2EBiometricAuthenticator implements BiometricAuthenticator {
  bool isBiometricAvailable = true;
  bool authSuccess = true;
  int promptCount = 0;

  @override
  Future<bool> canCheckBiometrics() async => isBiometricAvailable;

  @override
  Future<bool> isDeviceSupported() async => isBiometricAvailable;

  @override
  Future<bool> authenticate({required String reason}) async {
    promptCount++;
    return authSuccess;
  }
}

class E2ESecureStorage extends FlutterSecureStorage {
  final Map<String, String> _data = {};

  E2ESecureStorage() : super();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _data[key];

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
      _data[key] = value;
    } else {
      _data.remove(key);
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
    _data.remove(key);
  }
}

void main() {
  group(
    'Tier 4 Real-World E2E Scenario: Biometric Auth & Resilient Token Refresh',
    () {
      late E2EAuthRepository authRepository;
      late E2EBiometricAuthenticator biometricAuth;
      late E2ESecureStorage secureStorage;
      late AuthBloc authBloc;

      setUp(() {
        authRepository = E2EAuthRepository();
        biometricAuth = E2EBiometricAuthenticator();
        secureStorage = E2ESecureStorage();
        authBloc = AuthBloc(
          authRepository: authRepository,
          biometricAuthenticator: biometricAuth,
          storage: secureStorage,
        );
      });

      tearDown(() {
        authBloc.close();
      });

      test(
        'E2E: Password Login -> Enable Biometrics -> Cold Restart Unlock -> Soft Expiry Refresh -> Graceful Expired Logout',
        () async {
          // Phase 1: User logs in with password
          authBloc.add(
            const LoginSubmitted(
              username: 'farzod_director',
              password: 'secure_password_123',
              storeId: 1,
            ),
          );

          var state =
              await authBloc.stream.firstWhere((s) => s is AuthAuthenticated)
                  as AuthAuthenticated;
          expect(state.username, 'farzod_director');
          expect(state.role, UserRole.director);
          expect(state.accessTokenExpiresAt, isNotNull);

          // Phase 2: User enables Biometric Login in settings
          await secureStorage.write(key: 'use_biometrics', value: 'true');

          // Phase 3: Cold restart / app re-entry triggering CheckAuthStatus
          authBloc.add(CheckAuthStatus());
          state =
              await authBloc.stream.firstWhere((s) => s is AuthAuthenticated)
                  as AuthAuthenticated;
          expect(biometricAuth.promptCount, 1);
          expect(state.username, 'farzod_director');

          // Phase 4: Token approaches soft expiry lead time
          final initialExpiry = state.accessTokenExpiresAt!;
          authBloc.add(const SessionSoftExpiryReached());

          state =
              await authBloc.stream.firstWhere(
                    (s) =>
                        s is AuthAuthenticated &&
                        s.accessTokenExpiresAt!.isAfter(initialExpiry),
                  )
                  as AuthAuthenticated;
          expect(authRepository.refreshCount, 1);
          expect(state.accessTokenExpiresAt!.isAfter(initialExpiry), isTrue);

          // Phase 5: Refresh token revoked / rejected by server on subsequent expiry check
          authRepository.shouldFailRefresh = true;
          authBloc.add(const SessionSoftExpiryReached());

          final unauthState = await authBloc.stream.firstWhere(
            (s) => s is AuthUnauthenticated,
          );
          expect(unauthState, isA<AuthUnauthenticated>());
          expect(authRepository.logoutCount, 1);
          expect(authRepository.currentUser, isNull);
        },
      );
    },
  );
}
