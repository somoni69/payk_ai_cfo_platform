import 'package:equatable/equatable.dart';

import '../../network/domain/network_models.dart';
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

  /// ID действующего магазина (если выбран или привязан).
  final int? storeId;

  /// Название действующего магазина (если известно).
  final String? storeName;

  /// UTC expiry of the access JWT when available.
  final DateTime? accessTokenExpiresAt;

  const AuthAuthenticated({
    this.id,
    required this.username,
    this.name = '',
    required this.role,
    this.storeId,
    this.storeName,
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

  AuthAuthenticated copyWith({
    int? id,
    String? username,
    String? name,
    UserRole? role,
    int? storeId,
    String? storeName,
    bool clearStore = false,
    DateTime? accessTokenExpiresAt,
  }) {
    return AuthAuthenticated(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      role: role ?? this.role,
      storeId: clearStore ? null : (storeId ?? this.storeId),
      storeName: clearStore ? null : (storeName ?? this.storeName),
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    username,
    name,
    role,
    storeId,
    storeName,
    accessTokenExpiresAt,
  ];
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

/// The same login and password exist in more than one store.
class AuthChooseStore extends AuthState {
  final List<LoginChoice> choices;

  const AuthChooseStore(this.choices);

  @override
  List<Object?> get props => [choices];
}

class AuthError extends AuthState {
  /// Localization key or legacy Russian message (resolved via translate / translateMessage).
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
