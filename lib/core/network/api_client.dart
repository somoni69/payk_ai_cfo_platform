import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'expiring_request_cache.dart';
import 'safe_retry_interceptor.dart';

/// Сетевой клиент на базе Dio с поддержкой безопасного хранения JWT (SYS-08).
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'jwt_access_token';
  static const String _languageKey = 'interface_language';
  static const Set<String> _supportedLanguages = {'ru', 'tg'};
  static const String defaultBaseUrl =
      'https://payk-ecosystem-production.up.railway.app/api';
  static const String configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultBaseUrl,
  );
  static const bool allowInsecureApi = bool.fromEnvironment(
    'ALLOW_INSECURE_API',
  );

  /// Timeout policy for opt-in AI/generation endpoints.
  static Options longRunningOptions({
    Duration receiveTimeout = const Duration(seconds: 90),
  }) {
    return Options(
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: receiveTimeout,
    );
  }

  String? _accessToken;
  String _interfaceLanguage = 'ru';
  Future<void>? _bootstrapFuture;
  Future<void>? _unauthorizedFuture;

  static int _requestSequence = 0;

  void Function()? onUnauthorized;

  /// The language used for both the interface and the Accept-Language header.
  String get interfaceLanguage => _interfaceLanguage;

  ApiClient._internal() {
    final baseUrl = _validatedBaseUrl();
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Интерцептор для подстановки JWT-токена в заголовки
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Accept-Language'] = _interfaceLanguage;
          options.headers.putIfAbsent('X-Request-ID', _nextRequestId);
          final token = _accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers.remove('Authorization');
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Автоматическое разлогирование при невалидном токене
          if (e.response?.statusCode == 401) {
            await _handleUnauthorized(e.requestOptions);
          }
          return handler.next(e);
        },
      ),
    );

    dio.interceptors.add(
      SafeRetryInterceptor(
        dio: dio,
        isSessionCurrent: _isRequestSessionCurrent,
      ),
    );
  }

  static String _nextRequestId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_requestSequence++}';

  /// Loads persistent request metadata once during application startup.
  ///
  /// Concurrent callers share the same read, so secure storage is touched only
  /// once even when several services initialize together.
  Future<void> bootstrap() {
    return _bootstrapFuture ??= _loadPersistentMetadata();
  }

  Future<void> _loadPersistentMetadata() async {
    final values = await Future.wait<String?>([
      _safeRead(_tokenKey),
      _safeRead(_languageKey),
    ]);
    _accessToken = values[0];
    final savedLanguage = values[1];
    if (savedLanguage != null && _supportedLanguages.contains(savedLanguage)) {
      _interfaceLanguage = savedLanguage;
    }
  }

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAccessToken(String token) async {
    if (_accessToken != token) {
      ExpiringRequestCache.invalidateAll();
    }
    await _storage.write(key: _tokenKey, value: token);
    _accessToken = token;
  }

  Future<String?> getAccessToken() async {
    await bootstrap();
    return _accessToken;
  }

  Future<void> clearAccessToken() async {
    if (_accessToken != null) ExpiringRequestCache.invalidateAll();
    _accessToken = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // The in-memory session is already invalidated.
    }
  }

  /// Updates the request header cache synchronously.
  /// Persistence remains owned by the localization layer.
  void cacheInterfaceLanguage(String languageCode) {
    if (_supportedLanguages.contains(languageCode)) {
      _interfaceLanguage = languageCode;
    }
  }

  Future<void> _handleUnauthorized(RequestOptions requestOptions) {
    final failedAuthorization = requestOptions.headers['Authorization'];
    final currentToken = _accessToken;

    // Ignore a late 401 from an old session and requests that had no session.
    if (currentToken == null || failedAuthorization != 'Bearer $currentToken') {
      return Future<void>.value();
    }

    final inFlight = _unauthorizedFuture;
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<void> operation;
    operation = _clearUnauthorizedSession().whenComplete(() {
      if (identical(_unauthorizedFuture, operation)) {
        _unauthorizedFuture = null;
      }
    });
    _unauthorizedFuture = operation;
    return operation;
  }

  bool _isRequestSessionCurrent(RequestOptions requestOptions) {
    final authorization = requestOptions.headers['Authorization'];
    if (authorization == null) return _accessToken == null;

    final token = _accessToken;
    return token != null && authorization == 'Bearer $token';
  }

  static String _validatedBaseUrl() {
    final value = configuredBaseUrl.trim();
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('API_BASE_URL must be an absolute URL');
    }

    if (uri.scheme != 'https' && !allowInsecureApi) {
      throw StateError(
        'API_BASE_URL must use HTTPS. '
        'Use --dart-define=ALLOW_INSECURE_API=true only for local development.',
      );
    }

    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  Future<void> _clearUnauthorizedSession() async {
    try {
      await clearAccessToken();
    } finally {
      onUnauthorized?.call();
    }
  }
}
