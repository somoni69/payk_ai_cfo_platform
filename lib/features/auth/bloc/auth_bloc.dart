import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
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

  /// Refresh / logout slightly before hard JWT expiry.
  static const Duration _softExpiryLead = Duration(minutes: 2);

  Timer? _sessionTimer;

  /// Last 2FA challenge while [AuthLoading] replaces [AuthTwoFactorRequired]
  /// during verify (so a failed verify can restore the challenge UI).
  AuthTwoFactorRequired? _pendingTwoFactor;

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

  @override
  Future<void> close() {
    _cancelSessionWatchdog();
    return super.close();
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
    if (event is TwoFactorSubmitted) {
      await _onTwoFactorSubmitted(event, emit);
      return;
    }
    if (event is TwoFactorCancelled) {
      _onTwoFactorCancelled(emit);
      return;
    }
    if (event is BiometricLoginRequested) {
      await _onBiometricLoginRequested(event, emit);
      return;
    }
    if (event is SessionSoftExpiryReached) {
      await _onSessionSoftExpiry(event, emit);
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
    _pendingTwoFactor = null;
    final user = await _authRepository.tryAutoLogin();
    if (user == null) {
      _cancelSessionWatchdog();
      emit(AuthUnauthenticated());
      return;
    }

    bool useBiometrics;
    try {
      useBiometrics = await _storage.read(key: 'use_biometrics') == 'true';
    } catch (_) {
      // A financial session must not bypass an enabled lock when its policy
      // cannot be read reliably.
      _cancelSessionWatchdog();
      emit(AuthUnauthenticated());
      return;
    }

    if (!useBiometrics) {
      _emitAuthenticated(emit, user);
      return;
    }

    try {
      final isAvailable = await _biometricsAvailable();
      if (!isAvailable) {
        _cancelSessionWatchdog();
        emit(AuthUnauthenticated());
        return;
      }

      final authenticated = await _biometricAuthenticator.authenticate(
        reason: _biometricReason(),
      );
      if (authenticated) {
        _emitAuthenticated(emit, user);
        return;
      }
    } catch (_) {
      // Fall through to manual authentication when the platform rejects it.
    }
    _cancelSessionWatchdog();
    emit(AuthUnauthenticated());
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    _pendingTwoFactor = null;
    try {
      final result = await _authRepository.login(
        event.username.trim(),
        event.password,
      );
      switch (result) {
        case LoginSuccess(:final user):
          _emitAuthenticated(emit, user);
        case LoginTwoFactorRequired(:final challengeId, :final username):
          final challenge = AuthTwoFactorRequired(
            challengeId: challengeId,
            username: username,
          );
          _pendingTwoFactor = challenge;
          _cancelSessionWatchdog();
          emit(challenge);
      }
    } catch (e) {
      _cancelSessionWatchdog();
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onTwoFactorSubmitted(
    TwoFactorSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final challenge = _pendingTwoFactor ??
        (state is AuthTwoFactorRequired
            ? state as AuthTwoFactorRequired
            : null);
    if (challenge == null) {
      emit(const AuthError(ErrorKeys.twoFactorFailed));
      return;
    }

    final code = event.code.trim();
    if (code.isEmpty) {
      emit(const AuthError(ErrorKeys.twoFactorValidation));
      // Restore challenge UI after the error snackbar path.
      emit(challenge);
      return;
    }

    emit(AuthLoading());
    try {
      final result = await _authRepository.verifyTwoFactor(
        challengeId: challenge.challengeId,
        code: code,
        username: challenge.username,
      );
      switch (result) {
        case LoginSuccess(:final user):
          _pendingTwoFactor = null;
          _emitAuthenticated(emit, user);
        case LoginTwoFactorRequired():
          _pendingTwoFactor = challenge;
          emit(const AuthError(ErrorKeys.twoFactorFailed));
          emit(challenge);
      }
    } catch (e) {
      _pendingTwoFactor = challenge;
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
      emit(challenge);
    }
  }

  void _onTwoFactorCancelled(Emitter<AuthState> emit) {
    _pendingTwoFactor = null;
    _cancelSessionWatchdog();
    emit(AuthUnauthenticated());
  }

  Future<void> _onBiometricLoginRequested(
    BiometricLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    _pendingTwoFactor = null;
    try {
      final isAvailable = await _biometricsAvailable();
      if (!isAvailable) {
        emit(const AuthError(ErrorKeys.biometricsUnavailable));
        return;
      }

      final user = await _authRepository.tryAutoLogin();
      if (user == null) {
        emit(const AuthError(ErrorKeys.biometricsNoSession));
        return;
      }

      final authenticated = await _biometricAuthenticator.authenticate(
        reason: _biometricReason(),
      );

      if (authenticated) {
        _emitAuthenticated(emit, user);
      } else {
        emit(const AuthError(ErrorKeys.biometricsFailed));
      }
    } catch (e) {
      emit(const AuthError(ErrorKeys.biometricsError));
    }
  }

  Future<void> _onSessionSoftExpiry(
    SessionSoftExpiryReached event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! AuthAuthenticated) return;

    final refreshed = await _authRepository.tryRefreshSession();
    if (refreshed != null) {
      _emitAuthenticated(emit, refreshed);
      return;
    }

    _cancelSessionWatchdog();
    await _authRepository.logout();
    emit(const AuthError(ErrorKeys.sessionExpired));
    emit(AuthUnauthenticated());
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

  void _emitAuthenticated(Emitter<AuthState> emit, AuthUser user) {
    _pendingTwoFactor = null;
    emit(
      AuthAuthenticated(
        id: user.id,
        username: user.username,
        name: user.name,
        role: user.role,
        accessTokenExpiresAt: user.accessTokenExpiresAt,
      ),
    );
    _scheduleSessionWatchdog(user.accessTokenExpiresAt);
  }

  void _scheduleSessionWatchdog(DateTime? expiresAt) {
    _cancelSessionWatchdog();
    if (expiresAt == null) return;

    final fireAt = expiresAt.toUtc().subtract(_softExpiryLead);
    final delay = fireAt.difference(DateTime.now().toUtc());
    if (delay.isNegative) {
      add(const SessionSoftExpiryReached());
      return;
    }

    _sessionTimer = Timer(delay, () {
      if (!isClosed) add(const SessionSoftExpiryReached());
    });
  }

  void _cancelSessionWatchdog() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    _cancelSessionWatchdog();
    _pendingTwoFactor = null;
    emit(AuthLoading());
    await _authRepository.logout();
    emit(AuthUnauthenticated());
  }
}
