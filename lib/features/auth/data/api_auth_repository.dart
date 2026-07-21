import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../bloc/auth_state.dart';

/// Репозиторий авторизации, работающий с реальным бэкендом PAYK.
class ApiAuthRepository {
  final ApiClient _apiClient;

  ApiAuthRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Выполнить авторизацию через API (вход по логину/паролю)
  Future<AuthUser> login(String username, String password) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );

      final token = response.data is Map
          ? (response.data as Map)['access_token']
          : null;
      if (token is! String || token.isEmpty) {
        throw const FormatException('Login response has no valid access token');
      }
      final user = decodeUserFromToken(token, fallbackUsername: username);
      await _apiClient.saveAccessToken(token);
      return user;
    } on DioException catch (error) {
      final errorMessage = switch (error.response?.statusCode) {
        400 || 401 => 'Неверный логин или пароль',
        403 => 'Вход для этой учётной записи запрещён',
        422 => 'Проверьте логин и пароль',
        429 => 'Слишком много попыток входа. Повторите позже.',
        _ => 'Сервис авторизации временно недоступен',
      };
      throw Exception(errorMessage);
    } catch (_) {
      throw Exception('Не удалось выполнить вход. Повторите попытку.');
    }
  }

  /// Попытка восстановить сессию при запуске приложения
  Future<AuthUser?> tryAutoLogin() async {
    final token = await _apiClient.getAccessToken();
    if (token == null || token.isEmpty) return null;

    try {
      return decodeUserFromToken(token);
    } catch (_) {
      await _apiClient.clearAccessToken();
      return null;
    }
  }

  /// Выйти из системы
  Future<void> logout() async {
    await _apiClient.clearAccessToken();
  }

  /// Parses and validates the claims required to restore a local session.
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

    final usernameClaim =
        claims['sub'] ?? claims['username'] ?? fallbackUsername;
    if (usernameClaim is! String || usernameClaim.trim().isEmpty) {
      throw const FormatException('JWT has no valid user identity');
    }
    final username = usernameClaim.trim();
    final roleClaim = _stringRoleClaim(
      claims['role'] ?? claims['user_role'] ?? claims['scope'],
    );

    return AuthUser(username: username, role: _mapRole(roleClaim, username));
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

  static UserRole _mapRole(String? roleClaim, String username) {
    final cleanRole = (roleClaim ?? username).toLowerCase();
    if (cleanRole.contains('director') || cleanRole.contains('admin')) {
      return UserRole.director;
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
    if (cleanRole.contains('viewer')) {
      return UserRole.viewer;
    }
    return UserRole.viewer;
  }
}

/// Промежуточный класс для возврата пользователя из репозитория
class AuthUser {
  final String username;
  final UserRole role;

  const AuthUser({required this.username, required this.role});
}
