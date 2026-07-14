import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Сетевой клиент на базе Dio с поддержкой безопасного хранения JWT (SYS-08).
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final _storage = const FlutterSecureStorage();
  
  static const String _tokenKey = 'jwt_access_token';

  Function()? onUnauthorized;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: 'https://payk-ecosystem-production.up.railway.app/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    // Интерцептор для подстановки JWT-токена в заголовки
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Автоматическое разлогирование при невалидном токене
          if (e.response?.statusCode == 401) {
            await clearAccessToken();
            onUnauthorized?.call();
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> clearAccessToken() async {
    await _storage.delete(key: _tokenKey);
  }
}
