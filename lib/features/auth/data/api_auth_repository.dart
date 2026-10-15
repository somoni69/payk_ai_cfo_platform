import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/user_facing_error.dart';
import '../../network/domain/network_models.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import '../domain/user_role.dart';

export '../../network/domain/network_models.dart';
export '../domain/auth_repository.dart';
export '../domain/auth_user.dart';
export '../domain/user_role.dart';

/// Same login and password matched more than one account.
class ChooseStoreRequired implements Exception {
  final List<LoginChoice> choices;

  const ChooseStoreRequired(this.choices);
}

/// Reads a 409 `{code: choose_store, stores: [...]}` body. Null for other errors.
List<LoginChoice>? loginChoicesFromError(DioException error) {
  if (error.response?.statusCode != 409) return null;
  final data = error.response?.data;
  if (data is! Map) return null;
  final detail = data['detail'];
  if (detail is! Map || detail['code'] != 'choose_store') return null;
  final stores = detail['stores'];
  if (stores is! List) return null;
  return [
    for (final item in stores.whereType<Map>())
      LoginChoice.fromJson(Map<String, dynamic>.from(item)),
  ];
}

/// Outcome of [ApiAuthRepository.login] / [ApiAuthRepository.verifyTwoFactor].
sealed class LoginResult {
  const LoginResult();
}

/// Password (or 2FA) succeeded — session tokens are persisted.
final class LoginSuccess extends LoginResult {
  final AuthUser user;

  const LoginSuccess(this.user);
}

/// SMS 2FA required — no tokens yet; continue with [ApiAuthRepository.verifyTwoFactor].
final class LoginTwoFactorRequired extends LoginResult {
  final String challengeId;
  final String username;

  const LoginTwoFactorRequired({
    required this.challengeId,
    required this.username,
  });
}

/// Репозиторий авторизации, работающий с бэкендом PAYK.
///
/// ## JWT threat model (client)
/// Access tokens are treated as **bearer secrets** stored in secure storage.
/// Claims (`exp`, `nbf`, optional `iss`/`aud`) are decoded **without**
/// cryptographic signature verification: the API remains the authority for
/// every protected request. Local claim checks only prevent obviously expired
/// or malformed sessions from hydrating the UI. Production builds should set
/// `--dart-define=JWT_ISSUER` / `JWT_AUDIENCE` when the backend emits them.
///
/// ## Tokens
/// - **access** ~30 minutes — short-lived bearer for API calls.
/// - **refresh** ~14 days — stored only in Keychain/Keystore via
///   [FlutterSecureStorage]; **no rotation** on refresh (backend returns only
///   a new [AccessToken]; the same refresh token remains valid until expiry).
/// - **logout** is client-only (no `/auth/logout`); both tokens are wiped locally.
///
/// ## Access JWT claims (local, no network)
/// `sub` (user id), `role`, `name` — enough for shell UI and ACL.
/// Full profile: [fetchCurrentUser] → `GET /auth/me`.
///
/// ## Login limits (backend)
/// 10 attempts/min per IP+login, 40/min per IP → HTTP 429.
/// Blocked account → HTTP 403. `/auth/refresh` is not rate-limited; still
/// soft-expire only (~2 min before access `exp`), do not poll.
class ApiAuthRepository implements AuthRepository {
  final ApiClient _apiClient;

  ApiAuthRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Fetches the public list of active stores for login screen.
  @override
  Future<List<LoginStore>> fetchLoginStores() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/auth/stores');
      final list = response.data is List ? response.data as List : const [];
      return list
          .whereType<Map>()
          .map((m) => LoginStore.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Login with username/password.
  ///
  /// The store is resolved by the server. [storeId] and [asOwner] are sent only
  /// after a 409 `choose_store` — the same login exists in several stores.
  /// May return [LoginTwoFactorRequired] when SMS 2FA is enabled for the user.
  @override
  Future<LoginResult> login(
    String username,
    String password, {
    int? storeId,
    bool asOwner = false,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
          'store_id': ?storeId,
          if (asOwner) 'as_owner': true,
        },
        options: Options(
          extra: const <String, dynamic>{'skipUnauthorizedHandler': true},
        ),
      );

      return await _parseLoginBody(response.data, fallbackUsername: username);
    } on ChooseStoreRequired {
      rethrow;
    } on DioException catch (error) {
      final choices = loginChoicesFromError(error);
      if (choices != null && choices.isNotEmpty) {
        throw ChooseStoreRequired(choices);
      }
      throw AuthFailure(
        translationKey: _loginErrorKey(error),
        debugMessage: error.message,
      );
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw const AuthFailure(translationKey: ErrorKeys.loginFailed);
    }
  }

  /// Completes an SMS 2FA challenge started by [login].
  @override
  Future<LoginResult> verifyTwoFactor({
    required String challengeId,
    required String code,
    required String username,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/verify-2fa',
        data: {'challenge_id': challengeId, 'code': code.trim()},
        options: Options(
          extra: const <String, dynamic>{'skipUnauthorizedHandler': true},
        ),
      );

      final result = await _parseLoginBody(
        response.data,
        fallbackUsername: username,
      );
      if (result is LoginTwoFactorRequired) {
        // Nested 2FA is not expected from verify-2fa.
        throw const AuthFailure(translationKey: ErrorKeys.loginFailed);
      }
      return result;
    } on DioException catch (error) {
      throw AuthFailure(
        translationKey: _twoFactorErrorKey(error),
        debugMessage: error.message,
      );
    } catch (error) {
      if (error is AppFailure) rethrow;
      throw const AuthFailure(translationKey: ErrorKeys.twoFactorFailed);
    }
  }

  /// Exchanges the stored refresh token for a new access token.
  ///
  /// **No rotation:** only [access_token] is saved; the existing refresh token
  /// is left as-is until its 14-day lifetime ends.
  ///
  /// On 401 (invalid/expired refresh or blocked user) both tokens are cleared
  /// and `null` is returned so the caller can force re-login.
  @override
  Future<AuthUser?> tryRefreshSession() async {
    final refreshToken = await _apiClient.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final response = await _apiClient.dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(
          // Avoid recursive 401 → logout while refreshing.
          extra: const <String, dynamic>{'skipUnauthorizedHandler': true},
        ),
      );
      final body = response.data is Map ? response.data as Map : null;
      final token = body?['access_token'];
      if (token is! String || token.isEmpty) return null;

      final user = decodeUserFromToken(token);
      await _apiClient.saveAccessToken(token);
      // No refresh rotation — do not overwrite the stored refresh token.
      return user;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401) {
        // Invalid refresh, wrong type, expired, or user blocked/deleted.
        await _apiClient.clearAccessToken();
        await _apiClient.clearRefreshToken();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Restores a session on cold start from secure storage.
  @override
  Future<AuthUser?> tryAutoLogin() async {
    final token = await _apiClient.getAccessToken();
    if (token != null && token.isNotEmpty) {
      try {
        return decodeUserFromToken(token);
      } catch (_) {
        // Access expired or malformed — fall through to refresh.
      }
    }

    final refreshed = await tryRefreshSession();
    if (refreshed != null) return refreshed;

    // Leave a bare expired access token out of storage when refresh is gone.
    if (token != null && token.isNotEmpty) {
      await _apiClient.clearAccessToken();
    }
    return null;
  }

  /// Client-only logout: wipe both tokens (no server revoke endpoint).
  @override
  Future<void> logout() async {
    await _apiClient.clearAccessToken();
    await _apiClient.clearRefreshToken();
  }

  /// Full profile from the API (`UserRead`). Prefer JWT claims for role/name.
  @override
  Future<AuthUser> fetchCurrentUser() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/auth/me');
      final body = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : null;
      if (body == null) {
        throw const FormatException('auth/me response is not a JSON object');
      }

      DateTime? expiresAt;
      final token = await _apiClient.getAccessToken();
      if (token != null && token.isNotEmpty) {
        try {
          expiresAt = decodeUserFromToken(token).accessTokenExpiresAt;
        } catch (_) {
          // Profile is still usable without local exp.
        }
      }

      return _userFromMeBody(body, accessTokenExpiresAt: expiresAt);
    } on DioException catch (error) {
      throw Exception(userFacingError(error, fallback: ErrorKeys.loadFailed));
    } catch (_) {
      throw Exception(ErrorKeys.loadFailed);
    }
  }

  Future<LoginResult> _parseLoginBody(
    Object? data, {
    required String fallbackUsername,
  }) async {
    final body = data is Map ? data : null;
    if (body == null) {
      throw const FormatException('Login response is not a JSON object');
    }

    final twoFactorRequired = body['two_factor_required'] == true;
    final challengeRaw = body['challenge_id'];
    final challengeId = challengeRaw is String ? challengeRaw.trim() : '';

    if (twoFactorRequired) {
      if (challengeId.isEmpty) {
        throw const FormatException('2FA challenge_id is missing');
      }
      // Ensure no half-session lingers while waiting for SMS code.
      await _apiClient.clearAccessToken();
      await _apiClient.clearRefreshToken();
      return LoginTwoFactorRequired(
        challengeId: challengeId,
        username: fallbackUsername,
      );
    }

    final token = body['access_token'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('Login response has no valid access token');
    }

    // LoginResult / TokenPair always includes refresh when 2FA is not required.
    final refresh = body['refresh_token'];
    if (refresh is! String || refresh.isEmpty) {
      throw const FormatException('Login response has no valid refresh token');
    }

    final user = decodeUserFromToken(token, fallbackUsername: fallbackUsername);
    await _apiClient.saveAccessToken(token);
    await _apiClient.saveRefreshToken(refresh);

    return LoginSuccess(user);
  }

  static AuthUser _userFromMeBody(
    Map<String, dynamic> body, {
    DateTime? accessTokenExpiresAt,
  }) {
    final idRaw = body['id'];
    final id = switch (idRaw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };
    final username = (body['username'] is String)
        ? (body['username'] as String).trim()
        : '';
    final fullName = (body['full_name'] is String)
        ? (body['full_name'] as String).trim()
        : '';
    final roleClaim = _stringRoleClaim(body['role']);
    final storeIdRaw = body['store_id'] ?? body['store'];
    final storeId = switch (storeIdRaw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };
    final storeName = (body['store_name'] is String)
        ? (body['store_name'] as String).trim()
        : null;

    if (username.isEmpty && id == null) {
      throw const FormatException('auth/me has no user identity');
    }

    return AuthUser(
      id: id,
      username: username.isNotEmpty ? username : (id != null ? 'user-$id' : ''),
      name: fullName,
      role: _mapRole(roleClaim),
      storeId: storeId,
      storeName: storeName,
      accessTokenExpiresAt: accessTokenExpiresAt,
    );
  }

  static String _loginErrorKey(DioException error) {
    // 403 = blocked account; 429 = IP/login rate limit (10/min pair, 40/min IP).
    return switch (error.response?.statusCode) {
      400 || 401 => ErrorKeys.loginInvalid,
      403 => ErrorKeys.loginForbidden,
      422 => ErrorKeys.loginValidation,
      429 => ErrorKeys.loginRateLimited,
      _ => ErrorKeys.loginUnavailable,
    };
  }

  static String _twoFactorErrorKey(DioException error) {
    return switch (error.response?.statusCode) {
      400 || 401 => ErrorKeys.twoFactorInvalid,
      403 => ErrorKeys.loginForbidden,
      422 => ErrorKeys.twoFactorValidation,
      429 => ErrorKeys.loginRateLimited,
      _ => ErrorKeys.twoFactorFailed,
    };
  }

  /// Parses access JWT claims for local session restore.
  ///
  /// Production tokens carry:
  /// - `sub` — user id (numeric string or number)
  /// - `role` — owner | director | manager | accountant | cashier | hr | viewer
  /// - `name` — display name
  /// - `store` — store id when entered/scoped
  /// - `exp` — access lifetime (~30 min)
  static AuthUser decodeUserFromToken(
    String token, {
    String? fallbackUsername,
    DateTime? now,
  }) {
    final claims = _decodeJwt(token);
    final expiration = claims['exp'];
    if (expiration is! num || !expiration.isFinite) {
      throw const FormatException('JWT must have a valid expiration');
    }
    final clock = (now ?? DateTime.now()).toUtc();
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      expiration.toInt() * 1000,
      isUtc: true,
    );
    if (!clock.isBefore(expiresAt)) {
      throw const FormatException('JWT has expired');
    }

    _validateRegisteredClaims(claims, clock);

    final sub = claims['sub'];
    if (sub == null) {
      throw const FormatException('JWT has no valid user identity');
    }
    final id = _parseUserId(sub);
    final subAsString = switch (sub) {
      String s => s.trim(),
      num n => n.toInt().toString(),
      _ => sub.toString(),
    };
    if (subAsString.isEmpty) {
      throw const FormatException('JWT has no valid user identity');
    }

    final nameClaim = claims['name'] ?? claims['full_name'];
    final name = nameClaim is String ? nameClaim.trim() : '';

    final usernameClaim = claims['username'] ?? claims['preferred_username'];
    final fromClaim = usernameClaim is String ? usernameClaim.trim() : '';
    final fallback = fallbackUsername?.trim() ?? '';
    final username = fromClaim.isNotEmpty
        ? fromClaim
        : (fallback.isNotEmpty
              ? fallback
              : (id != null ? 'user-$id' : subAsString));

    final roleClaim = _stringRoleClaim(
      claims['role'] ?? claims['user_role'] ?? claims['scope'],
    );

    final storeClaim = claims['store'] ?? claims['store_id'];
    final storeId = switch (storeClaim) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v),
      _ => null,
    };

    return AuthUser(
      id: id,
      username: username,
      name: name,
      role: _mapRole(roleClaim),
      storeId: storeId,
      accessTokenExpiresAt: expiresAt,
    );
  }

  static int? _parseUserId(Object? sub) {
    if (sub is int) return sub;
    if (sub is num) return sub.toInt();
    if (sub is String) return int.tryParse(sub.trim());
    return null;
  }

  static Map<String, dynamic> _decodeJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
      throw const FormatException('Invalid JWT format');
    }

    final header = json.decode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
    );
    if (header is! Map<String, dynamic> ||
        header['alg'] is! String ||
        (header['alg'] as String).isEmpty ||
        header['alg'] == 'none') {
      throw const FormatException('Invalid JWT header');
    }
    // Presence check only — not cryptographic verification (see class docs).
    if (base64Url.decode(base64Url.normalize(parts[2])).isEmpty) {
      throw const FormatException('Invalid JWT signature');
    }

    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final decoded = json.decode(payload);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JWT payload');
    }
    return decoded;
  }

  static void _validateRegisteredClaims(
    Map<String, dynamic> claims,
    DateTime clock,
  ) {
    final notBefore = claims['nbf'];
    if (notBefore != null) {
      if (notBefore is! num || !notBefore.isFinite) {
        throw const FormatException('Invalid JWT not-before claim');
      }
      final validFrom = DateTime.fromMillisecondsSinceEpoch(
        notBefore.toInt() * 1000,
        isUtc: true,
      );
      if (clock.isBefore(validFrom)) {
        throw const FormatException('JWT is not active yet');
      }
    }

    const expectedIssuer = String.fromEnvironment('JWT_ISSUER');
    if (expectedIssuer.isNotEmpty && claims['iss'] != expectedIssuer) {
      throw const FormatException('Unexpected JWT issuer');
    }

    const expectedAudience = String.fromEnvironment('JWT_AUDIENCE');
    if (expectedAudience.isNotEmpty) {
      final audience = claims['aud'];
      final matches =
          audience == expectedAudience ||
          (audience is Iterable && audience.contains(expectedAudience));
      if (!matches) {
        throw const FormatException('Unexpected JWT audience');
      }
    }
  }

  static String? _stringRoleClaim(Object? value) {
    if (value is String) return value;
    if (value is Iterable) return value.join(' ');
    return null;
  }

  /// Maps backend [Role] enum values (and a few aliases) to [UserRole].
  static UserRole _mapRole(String? roleClaim) {
    if (roleClaim == null || roleClaim.trim().isEmpty) {
      return UserRole.viewer;
    }
    final cleanRole = roleClaim.toLowerCase().trim();
    // Exact OpenAPI Role enum first.
    switch (cleanRole) {
      case 'owner':
        return UserRole.owner;
      case 'director':
        return UserRole.director;
      case 'manager':
        return UserRole.manager;
      case 'accountant':
        return UserRole.accountant;
      case 'cashier':
        return UserRole.cashier;
      case 'hr':
        return UserRole.hr;
      case 'marketer':
      case 'marketing':
        return UserRole.marketer;
      case 'viewer':
        return UserRole.viewer;
    }
    // Loose aliases for older tokens / combined scopes.
    if (cleanRole.contains('owner')) {
      return UserRole.owner;
    }
    if (cleanRole.contains('director') || cleanRole.contains('admin')) {
      return UserRole.director;
    }
    if (cleanRole.contains('marketer') || cleanRole.contains('marketolog')) {
      return UserRole.marketer;
    }
    if (cleanRole.contains('manager')) {
      return UserRole.manager;
    }
    if (cleanRole.contains('accountant') || cleanRole.contains('buh')) {
      return UserRole.accountant;
    }
    if (cleanRole.contains('cashier') || cleanRole.contains('kassir')) {
      return UserRole.cashier;
    }
    if (cleanRole.contains('hr')) {
      return UserRole.hr;
    }
    return UserRole.viewer;
  }
}
