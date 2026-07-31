import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/network/api_client.dart';
import '../data/api_auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

abstract interface class BiometricAuthenticator {
  Future<bool> canCheckBiometrics();

  Future<bool> isDeviceSupported();

  Future<bool> authenticate({required String reason});
}

class DeviceBiometricAuthenticator implements BiometricAuthenticator {
  final LocalAuthentication _localAuthentication;

  DeviceBiometricAuthenticator({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  @override
  Future<bool> canCheckBiometrics() => _localAuthentication.canCheckBiometrics;

  @override
  Future<bool> isDeviceSupported() => _localAuthentication.isDeviceSupported();

  @override
  Future<bool> authenticate({required String reason}) {
    return _localAuthentication.authenticate(
      localizedReason: reason,
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiAuthRepository _authRepository;
  final BiometricAuthenticator _biometricAuthenticator;
  final FlutterSecureStorage _storage;

  AuthBloc({
    ApiAuthRepository? authRepository,
    BiometricAuthenticator? biometricAuthenticator,
    FlutterSecureStorage? storage,
  }) : _authRepository = authRepository ?? ApiAuthRepository(),
       _biometricAuthenticator =
           biometricAuthenticator ?? DeviceBiometricAuthenticator(),
       _storage = storage ?? const FlutterSecureStorage(),
       super(AuthInitial()) {
    on<AuthEvent>(
      _onAuthEvent,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  Future<void> _onAuthEvent(AuthEvent event, Emitter<AuthState> emit) async {
    if (event is CheckAuthStatus) {
      await _onCheckAuthStatus(event, emit);
      return;
    }
    if (event is LoginSubmitted) {
      await _onLoginSubmitted(event, emit);
      return;
    }
    if (event is BiometricLoginRequested) {
      await _onBiometricLoginRequested(event, emit);
      return;
    }
    if (event is LogoutRequested) {
      await _onLogoutRequested(event, emit);
    }
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final user = await _authRepository.tryAutoLogin();
    if (user == null) {
      emit(AuthUnauthenticated());
      return;
    }

    bool useBiometrics;
    try {
      useBiometrics = await _storage.read(key: 'use_biometrics') == 'true';
    } catch (_) {
      // A financial session must not bypass an enabled lock when its policy
      // cannot be read reliably.
      emit(AuthUnauthenticated());
      return;
    }

    if (!useBiometrics) {
      emit(AuthAuthenticated(username: user.username, role: user.role));
      return;
    }

    try {
      final isAvailable = await _biometricsAvailable();
      if (!isAvailable) {
        emit(AuthUnauthenticated());
        return;
      }

      final authenticated = await _biometricAuthenticator.authenticate(
        reason: _biometricReason(),
      );
      if (authenticated) {
        emit(AuthAuthenticated(username: user.username, role: user.role));
        return;
      }
    } catch (_) {
      // Fall through to manual authentication when the platform rejects it.
    }
    emit(AuthUnauthenticated());
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.login(
        event.username.trim(),
        event.password,
      );
      emit(AuthAuthenticated(username: user.username, role: user.role));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onBiometricLoginRequested(
    BiometricLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final isAvailable = await _biometricsAvailable();
      if (!isAvailable) {
        emit(const AuthError('Биометрия недоступна на этом устройстве'));
        return;
      }

      final user = await _authRepository.tryAutoLogin();
      if (user == null) {
        emit(
          const AuthError(
            'Нет сохраненной сессии. Пожалуйста, сначала войдите по паролю.',
          ),
        );
        return;
      }

      final authenticated = await _biometricAuthenticator.authenticate(
        reason: _biometricReason(),
      );

      if (authenticated) {
        emit(AuthAuthenticated(username: user.username, role: user.role));
      } else {
        emit(const AuthError('Аутентификация по биометрии не пройдена'));
      }
    } catch (e) {
      emit(
        const AuthError(
          'Не удалось выполнить биометрический вход. Войдите по паролю.',
        ),
      );
    }
  }

  Future<bool> _biometricsAvailable() async {
    final capabilities = await Future.wait<bool>([
      _biometricAuthenticator.canCheckBiometrics(),
      _biometricAuthenticator.isDeviceSupported(),
    ]);
    return capabilities.every((capability) => capability);
  }

  String _biometricReason() {
    return ApiClient().interfaceLanguage == 'tg'
        ? 'Барои ворид шудан ба PAYK Ledger шахсияти худро тасдиқ кунед'
        : 'Подтвердите личность для входа в PAYK Ledger';
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await _authRepository.logout();
    emit(AuthUnauthenticated());
  }
}
