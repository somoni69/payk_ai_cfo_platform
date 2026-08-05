import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends AuthEvent {
  final String username;
  final String password;

  const LoginSubmitted({required this.username, required this.password});

  @override
  // Passwords must never be included in Equatable's diagnostic output.
  List<Object?> get props => [username];
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

/// Internal: access token is about to expire or already expired.
class SessionSoftExpiryReached extends AuthEvent {
  const SessionSoftExpiryReached();
}
