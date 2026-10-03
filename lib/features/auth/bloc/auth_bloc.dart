import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/security/secure_storage_provider.dart';
import '../../network/data/api_network_repository.dart';
import '../../network/domain/network_repository.dart';
import '../data/api_auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

abstract interface class BiometricAuthenticator {
  Future<bool> canCheckBiometrics();

  Future<bool> isDeviceSupported();

  Future<bool> authenticate({required String reason});
}

class DeviceBiometricAuthenticator implements BiometricAuthenticator {
  final BiometricService _biometricService;

  DeviceBiometricAuthenticator({BiometricService? biometricService})
    : _biometricService = biometricService ?? BiometricService();

  @override
  Future<bool> canCheckBiometrics() => _biometricService.canCheckBiometrics();

  @override
  Future<bool> isDeviceSupported() => _biometricService.isDeviceSupported();

  @override
  Future<bool> authenticate({required String reason}) {
    final lang = ApiClient().interfaceLanguage;
    return _biometricService.authenticate(
      localizedReason: reason,
      languageCode: lang,
    );
  }
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final NetworkRepository _networkRepository;
  final BiometricAuthenticator _biometricAuthenticator;
  final FlutterSecureStorage _storage;

  /// Refresh / logout slightly before hard JWT expiry.
  static const Duration _softExpiryLead = Duration(minutes: 2);

  Timer? _sessionTimer;

  /// Last 2FA challenge while [AuthLoading] replaces [AuthTwoFactorRequired]
  /// during verify (so a failed verify can restore the challenge UI).
  AuthTwoFactorRequired? _pendingTwoFactor;

  Completer<void>? _inFlightAuth;

  AuthBloc({
    AuthRepository? authRepository,
    NetworkRepository? networkRepository,
    BiometricAuthenticator? biometricAuthenticator,
    FlutterSecureStorage? storage,
  }) : _authRepository = authRepository ?? ApiAuthRepository(),
       _networkRepository = networkRepository ?? ApiNetworkRepository(),
       _biometricAuthenticator =
           biometricAuthenticator ?? DeviceBiometricAuthenticator(),
       _storage = storage ?? AppSecureStorage.instance,
       super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus, transformer: restartable());
    on<LoginSubmitted>(_onLoginSubmitted);
    on<TwoFactorSubmitted>(_onTwoFactorSubmitted, transformer: droppable());
    on<TwoFactorCancelled>(_onTwoFactorCancelled);
    on<BiometricLoginRequested>(
      _onBiometricLoginRequested,
      transformer: droppable(),
    );
    on<SessionSoftExpiryReached>(
      _onSessionSoftExpiry,
      transformer: restartable(),
    );
    on<ActingStoreUpdated>(_onActingStoreUpdated);
    on<LogoutRequested>(_onLogoutRequested);
  }

  @override
  Future<void> close() {
    _cancelSessionWatchdog();
    return super.close();
  }

  void _onActingStoreUpdated(
    ActingStoreUpdated event,
    Emitter<AuthState> emit,
  ) {
    if (state is AuthAuthenticated) {
      final current = state as AuthAuthenticated;
      emit(
        current.copyWith(
          storeId: event.storeId,
          storeName: event.storeName,
          clearStore: event.storeId == null,
        ),
      );
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

    // SEC-04: If biometrics are disabled or not configured, cold start requires
    // explicit authentication (login credentials) instead of a silent autologin bypass.
    if (!useBiometrics) {
      _cancelSessionWatchdog();
      emit(AuthUnauthenticated());
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
        await _emitAuthenticated(emit, user);
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
    final completer = Completer<void>();
    _inFlightAuth = completer;
    emit(AuthLoading());
    _pendingTwoFactor = null;
    try {
      final result = await _authRepository.login(
        event.username.trim(),
        event.password,
        storeId: event.storeId,
      );
      switch (result) {
        case LoginSuccess(:final user):
          await _emitAuthenticated(emit, user);
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
      emit(AuthError(userFacingError(e, fallback: ErrorKeys.loginFailed)));
    } finally {
      completer.complete();
      if (_inFlightAuth == completer) {
        _inFlightAuth = null;
      }
    }
  }

  Future<void> _onTwoFactorSubmitted(
    TwoFactorSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final challenge =
        _pendingTwoFactor ??
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
          await _emitAuthenticated(emit, user);
        case LoginTwoFactorRequired():
          _pendingTwoFactor = challenge;
          emit(const AuthError(ErrorKeys.twoFactorFailed));
          emit(challenge);
      }
    } catch (e) {
      _pendingTwoFactor = challenge;
      emit(AuthError(userFacingError(e, fallback: ErrorKeys.twoFactorFailed)));
      emit(challenge);
    }
  }

  void _onTwoFactorCancelled(
    TwoFactorCancelled event,
    Emitter<AuthState> emit,
  ) {
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
        await _emitAuthenticated(emit, user);
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
      await _emitAuthenticated(emit, refreshed);
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
        ? 'Барои ворид шудан ба PAYK шахсияти худро тасдиқ кунед'
        : 'Подтвердите личность для входа в PAYK';
  }

  Future<void> _emitAuthenticated(
    Emitter<AuthState> emit,
    AuthUser user,
  ) async {
    _pendingTwoFactor = null;
    var storeId = user.storeId;
    var storeName = user.storeName;
    if (user.role == UserRole.owner) {
      try {
        final acting = await _networkRepository.getActingStore();
        final stale =
            acting != null && (storeId == null || acting.id != storeId);
        if (stale) {
          await _networkRepository.clearActingStore();
        } else if (acting != null &&
            acting.id == storeId &&
            (storeName == null || storeName.isEmpty)) {
          storeName = acting.name;
        }
      } catch (_) {}
    }
    emit(
      AuthAuthenticated(
        id: user.id,
        username: user.username,
        name: user.name,
        role: user.role,
        storeId: storeId,
        storeName: storeName,
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
    if (_inFlightAuth != null) {
      await _inFlightAuth!.future;
    }
    _cancelSessionWatchdog();
    _pendingTwoFactor = null;
    emit(AuthLoading());
    await _authRepository.logout();
    try {
      await _networkRepository.clearActingStore();
    } catch (_) {}
    emit(AuthUnauthenticated());
  }
}
