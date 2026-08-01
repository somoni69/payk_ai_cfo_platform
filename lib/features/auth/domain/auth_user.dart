import 'user_role.dart';

/// Authenticated principal restored from JWT claims, login, or `GET /auth/me`.
///
/// Access JWT already carries enough for the shell UI:
/// - `sub` — user id
/// - `role` — one of [UserRole] backend values
/// - `name` — display name
///
/// Full profile (email, phone, branch, 2FA flag, …) is available via
/// [ApiAuthRepository.fetchCurrentUser] → `GET /auth/me`.
class AuthUser {
  /// Backend user id from JWT `sub` when it is numeric.
  final int? id;

  /// Login name when known (login form or `/auth/me`); may be empty for pure JWT restore.
  final String username;

  /// Display name from JWT `name` (or `full_name` from `/auth/me`).
  final String name;

  final UserRole role;

  /// UTC expiry of the access token when known (from JWT `exp`).
  final DateTime? accessTokenExpiresAt;

  const AuthUser({
    this.id,
    required this.username,
    this.name = '',
    required this.role,
    this.accessTokenExpiresAt,
  });

  /// Best label for profile UI: full name → login → `#id`.
  String get displayName {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) return trimmedName;
    final trimmedUser = username.trim();
    if (trimmedUser.isNotEmpty) return trimmedUser;
    if (id != null) return '#$id';
    return 'user';
  }

  AuthUser copyWith({
    int? id,
    String? username,
    String? name,
    UserRole? role,
    DateTime? accessTokenExpiresAt,
  }) {
    return AuthUser(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      role: role ?? this.role,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
    );
  }
}
