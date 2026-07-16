import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../data/api_auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiAuthRepository _authRepository;
  final LocalAuthentication _localAuth = LocalAuthentication();

  AuthBloc({ApiAuthRepository? authRepository})
      : _authRepository = authRepository ?? ApiAuthRepository(),
        super(AuthUnauthenticated()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<BiometricLoginRequested>(_onBiometricLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  void _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final user = await _authRepository.tryAutoLogin();
    if (user != null) {
      final useBiometrics = await const FlutterSecureStorage().read(key: 'use_biometrics') == 'true';
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (useBiometrics && isAvailable && isDeviceSupported) {
        try {
          final authenticated = await _localAuth.authenticate(
            localizedReason: 'Подтвердите личность для входа в PAYK Ledger',
            biometricOnly: true,
            persistAcrossBackgrounding: true,
          );
          if (authenticated) {
            emit(AuthAuthenticated(username: user.username, role: user.role));
            return;
          }
        } catch (_) {
          // Игнорируем ошибку и переходим на ручной ввод
        }
      } else {
        // Если биометрия отключена или не поддерживается, выполняем автологин напрямую
        emit(AuthAuthenticated(username: user.username, role: user.role));
        return;
      }
    }
    emit(AuthUnauthenticated());
  }

  void _onLoginSubmitted(LoginSubmitted event, Emitter<AuthState> emit) async {
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

  void _onBiometricLoginRequested(BiometricLoginRequested event, Emitter<AuthState> emit) async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!isAvailable || !isDeviceSupported) {
        emit(const AuthError('Биометрия недоступна на этом устройстве'));
        return;
      }

      // Проверяем, есть ли сохраненный токен сессии
      final user = await _authRepository.tryAutoLogin();
      if (user == null) {
        emit(const AuthError('Нет сохраненной сессии. Пожалуйста, сначала войдите по паролю.'));
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Подтвердите личность для входа в PAYK Ledger',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        emit(AuthAuthenticated(username: user.username, role: user.role));
      } else {
        emit(const AuthError('Аутентификация по биометрии не пройдена'));
      }
    } catch (e) {
      emit(AuthError('Ошибка биометрии: ${e.toString()}'));
    }
  }

  void _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await _authRepository.logout();
    emit(AuthUnauthenticated());
  }
}
