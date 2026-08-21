import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends AuthEvent {
  final String username;
  final String password;
  final int? storeId;

  const LoginSubmitted({
    required this.username,
    required this.password,
    this.storeId,
  });

  @override
  // Passwords must never be included in Equatable's diagnostic output.
  List<Object?> get props => [username, storeId];
}

/// SMS code for an in-progress 2FA challenge ([AuthTwoFactorRequired]).
class TwoFactorSubmitted extends AuthEvent {
  final String code;

  const TwoFactorSubmitted({required this.code});

  @override
  // Codes are secrets — keep them out of diagnostics.
  List<Object?> get props => [];
}

/// User cancelled the 2FA step and wants the password form again.
class TwoFactorCancelled extends AuthEvent {
  const TwoFactorCancelled();
}

class BiometricLoginRequested extends AuthEvent {}

class LogoutRequested extends AuthEvent {}

class CheckAuthStatus extends AuthEvent {}

/// Владелец сети вошёл в конкретный магазин или вышел в корень сети.
class ActingStoreUpdated extends AuthEvent {
  final int? storeId;
  final String? storeName;

  const ActingStoreUpdated({this.storeId, this.storeName});

  @override
  List<Object?> get props => [storeId, storeName];
}

/// Internal: access token is about to expire or already expired.
class SessionSoftExpiryReached extends AuthEvent {
  const SessionSoftExpiryReached();
}
