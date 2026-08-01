import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'expiring_request_cache.dart';
import 'safe_retry_interceptor.dart';

/// Сетевой клиент на базе Dio с поддержкой безопасного хранения JWT (SYS-08).
///
/// Access + refresh tokens live in [FlutterSecureStorage] (Keychain / Keystore).
/// Refresh is **not** rotated: only the access token is rewritten after
/// `POST /auth/refresh`. Logout is client-only (both keys deleted).
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'jwt_access_token';
  static const String _refreshTokenKey = 'jwt_refresh_token';
  static const String _languageKey = 'interface_language';
  static const Set<String> _supportedLanguages = {'ru', 'tg'};
  static const String _skipUnauthorizedExtra = 'skipUnauthorizedHandler';
  static const String _authRetryExtra = 'authRefreshRetried';
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
  String? _refreshToken;
  String _interfaceLanguage = 'ru';
  Future<void>? _bootstrapFuture;
  Future<void>? _unauthorizedFuture;
  Future<bool>? _refreshInFlight;

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
          final skipUnauthorized =
              e.requestOptions.extra[_skipUnauthorizedExtra] == true;
          final alreadyRetried =
              e.requestOptions.extra[_authRetryExtra] == true;

          if (!skipUnauthorized &&
              e.response?.statusCode == 401 &&
              !alreadyRetried) {
            final recovered = await _tryRefreshAndRetry(e, handler);
            if (recovered) return;
          } else if (!skipUnauthorized && e.response?.statusCode == 401) {
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
      _safeRead(_refreshTokenKey),
      _safeRead(_languageKey),
    ]);
    _accessToken = values[0];
    _refreshToken = values[1];
    final savedLanguage = values[2];
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

  Future<void> saveRefreshToken(String token) async {
    _refreshToken = token;
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
    } catch (_) {
      // In-memory refresh token still usable for this process.
    }
  }

  Future<String?> getRefreshToken() async {
    await bootstrap();
    return _refreshToken;
  }

  Future<void> clearRefreshToken() async {
    _refreshToken = null;
    try {
      await _storage.delete(key: _refreshTokenKey);
    } catch (_) {
      // Best-effort persistence cleanup.
    }
  }

  /// Updates the request header cache synchronously.
  /// Persistence remains owned by the localization layer.
  void cacheInterfaceLanguage(String languageCode) {
    if (_supportedLanguages.contains(languageCode)) {
      _interfaceLanguage = languageCode;
    }
  }

  /// On 401: try one shared refresh, retry the request once, else logout.
  Future<bool> _tryRefreshAndRetry(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final requestOptions = error.requestOptions;
    final failedAuthorization = requestOptions.headers['Authorization'];
    final currentToken = _accessToken;

    // Ignore late 401s from an old session and unauthenticated calls.
    if (currentToken == null ||
        failedAuthorization != 'Bearer $currentToken') {
      return false;
    }

    final refreshed = await _refreshAccessTokenOnce();
    if (!refreshed) {
      await _handleUnauthorized(requestOptions);
      return false;
    }

    try {
      final newToken = _accessToken;
      if (newToken == null || newToken.isEmpty) {
        await _handleUnauthorized(requestOptions);
        return false;
      }

      final headers = Map<String, dynamic>.from(requestOptions.headers);
      headers['Authorization'] = 'Bearer $newToken';

      final response = await dio.fetch<dynamic>(
        requestOptions.copyWith(
          headers: headers,
          extra: <String, dynamic>{
            ...requestOptions.extra,
            _authRetryExtra: true,
          },
        ),
      );
      handler.resolve(response);
      return true;
    } catch (_) {
      await _handleUnauthorized(requestOptions);
      return false;
    }
  }

  /// Single-flight refresh used by the 401 interceptor.
  ///
  /// No token rotation: only access is updated. Returns `false` and clears
  /// both tokens when the refresh endpoint rejects the session (401).
  Future<bool> _refreshAccessTokenOnce() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    late final Future<bool> operation;
    operation = _performAccessTokenRefresh().whenComplete(() {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
      }
    });
    _refreshInFlight = operation;
    return operation;
  }

  Future<bool> _performAccessTokenRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await dio.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(
          extra: const <String, dynamic>{
            _skipUnauthorizedExtra: true,
            _authRetryExtra: true,
          },
        ),
      );
      final body = response.data is Map ? response.data as Map : null;
      final token = body?['access_token'];
      if (token is! String || token.isEmpty) {
        return false;
      }
      // No rotation — never overwrite the stored refresh token here.
      await saveAccessToken(token);
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        try {
          await clearAccessToken();
          await clearRefreshToken();
        } catch (_) {
          // Best-effort local wipe.
        }
      }
      return false;
    } catch (_) {
      return false;
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
      await clearRefreshToken();
    } finally {
      onUnauthorized?.call();
    }
  }
}
