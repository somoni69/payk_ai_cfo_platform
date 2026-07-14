import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../bloc/auth_state.dart';

/// Репозиторий авторизации, работающий с реальным бэкендом PAYK.
class ApiAuthRepository {
  final ApiClient _apiClient = ApiClient();

  /// Выполнить авторизацию через API (вход по логину/паролю)
  Future<AuthUser> login(String username, String password) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
        },
      );

      final token = response.data['access_token'] as String;
      await _apiClient.saveAccessToken(token);

      // Декодируем JWT токен для извлечения роли и логина
      final claims = _decodeJwt(token);
      final String finalUsername = claims['sub'] ?? claims['username'] ?? username;
      final String? roleClaim = claims['role'] ?? claims['user_role'] ?? claims['scope'];
      
      UserRole role = _mapRole(roleClaim, finalUsername);

      return AuthUser(username: finalUsername, role: role);
    } on DioException catch (e) {
      final errorMsg = e.response?.data['detail'] ?? 'Неверный логин или пароль';
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Ошибка авторизации: ${e.toString()}');
    }
  }

  /// Попытка восстановить сессию при запуске приложения
  Future<AuthUser?> tryAutoLogin() async {
    final token = await _apiClient.getAccessToken();
    if (token == null) return null;

    try {
      // Опционально: можно сделать проверочный запрос на /auth/me
      // final response = await _apiClient.dio.get('/auth/me');
      
      final claims = _decodeJwt(token);

      // Проверяем срок действия токена (exp claim)
      final exp = claims['exp'] as int?;
      if (exp != null) {
        final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        if (DateTime.now().isAfter(expDate)) {
          // Токен просрочен - очищаем хранилище
          await _apiClient.clearAccessToken();
          return null;
        }
      }

      final String finalUsername = claims['sub'] ?? claims['username'] ?? 'User';
      final String? roleClaim = claims['role'] ?? claims['user_role'] ?? claims['scope'];
      
      UserRole role = _mapRole(roleClaim, finalUsername);

      return AuthUser(username: finalUsername, role: role);
    } catch (e) {
      // Если токен протух или невалидный
      await _apiClient.clearAccessToken();
      return null;
    }
  }

  /// Выйти из системы
  Future<void> logout() async {
    await _apiClient.clearAccessToken();
  }

  /// Парсер JWT токена
  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw Exception('Неверный формат JWT');
      }
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      return json.decode(resp) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  /// Вспомогательный маппер ролей
  UserRole _mapRole(String? roleClaim, String username) {
    final cleanRole = (roleClaim ?? username).toLowerCase();
    if (cleanRole.contains('director') || cleanRole.contains('admin')) {
      return UserRole.director;
    } else if (cleanRole.contains('manager')) {
      return UserRole.manager;
    } else if (cleanRole.contains('accountant') || cleanRole.contains('buh')) {
      return UserRole.accountant;
    } else if (cleanRole.contains('cashier') || cleanRole.contains('kassir')) {
      return UserRole.cashier;
    } else if (cleanRole.contains('hr')) {
      return UserRole.hr;
    } else if (cleanRole.contains('viewer')) {
      return UserRole.viewer;
    }
    return UserRole.director; // По умолчанию
  }
}

/// Промежуточный класс для возврата пользователя из репозитория
class AuthUser {
  final String username;
  final UserRole role;

  const AuthUser({required this.username, required this.role});
}
