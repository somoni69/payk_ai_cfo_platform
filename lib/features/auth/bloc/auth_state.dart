import 'package:equatable/equatable.dart';

import '../domain/user_role.dart';

export '../domain/user_role.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  /// Backend user id when known from JWT `sub` or `/auth/me`.
  final int? id;

  /// Login name when known.
  final String username;

  /// Display name from JWT `name` (preferred in UI).
  final String name;

  final UserRole role;

  /// UTC expiry of the access JWT when available.
  final DateTime? accessTokenExpiresAt;

  const AuthAuthenticated({
    this.id,
    required this.username,
    this.name = '',
    required this.role,
    this.accessTokenExpiresAt,
  });

  /// Profile label: full name → login → `#id`.
  String get displayName {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) return trimmedName;
    final trimmedUser = username.trim();
    if (trimmedUser.isNotEmpty) return trimmedUser;
    if (id != null) return '#$id';
    return username;
  }

  @override
  List<Object?> get props => [id, username, name, role, accessTokenExpiresAt];
}

/// Password accepted; waiting for SMS 2FA code.
class AuthTwoFactorRequired extends AuthState {
  final String challengeId;
  final String username;

  const AuthTwoFactorRequired({
    required this.challengeId,
    required this.username,
  });

  @override
  List<Object?> get props => [challengeId, username];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  /// Localization key or legacy Russian message (resolved via translate / translateMessage).
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
