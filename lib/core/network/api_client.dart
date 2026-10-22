import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../security/secure_storage_provider.dart';
import 'expiring_request_cache.dart';
import 'safe_retry_interceptor.dart';
import 'ssl_pinning.dart';

enum _RefreshOutcome { success, expired, transient }

/// Сетевой клиент на базе Dio с поддержкой безопасного хранения JWT (SYS-08).
///
/// Access + refresh tokens live in [FlutterSecureStorage] (Keychain / Keystore).
/// Refresh is **not** rotated: only the access token is rewritten after
/// `POST /auth/refresh`. Logout is client-only (both keys deleted).
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final _storage = AppSecureStorage.instance;

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
  Future<_RefreshOutcome>? _refreshInFlight;

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

    // SEC-03: release builds fail closed without a configured certificate pin.
    assertSslPinningConfigured(allowInsecure: allowInsecureApi);
    configureSslPinning(dio, allowInsecure: allowInsecureApi);

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

  /// Resolves full media URL without leaking JWT tokens in query parameters (SEC-02).
  /// Automatically upgrades insecure HTTP URLs to HTTPS in production (SEC-09).
  String mediaUrl(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      if (trimmed.startsWith('http://') && !allowInsecureApi) {
        return 'https://${trimmed.substring(7)}';
      }
      return trimmed;
    }
    final baseUrl = dio.options.baseUrl;
    final normalized = trimmed.replaceFirst(RegExp(r'^/+'), '');
    return '$baseUrl/$normalized';
  }

  /// Whether [url] points at the API origin and may receive the Bearer token.
  ///
  /// Chat attachments can contain external CDN links; credentials must never
  /// be forwarded to a third-party host.
  bool isSameOrigin(String url) {
    final target = Uri.tryParse(url.trim());
    final base = Uri.tryParse(dio.options.baseUrl);
    if (target == null || base == null) return false;
    if (!target.hasScheme || !base.hasScheme) return false;
    return target.origin == base.origin;
  }

  /// Downloads protected binary media over authorized HTTP stream (SEC-02).
  Future<Uint8List> downloadProtectedMedia(String path) async {
    final response = await dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'Protected media response body was empty',
        response: response,
      );
    }
    return Uint8List.fromList(data);
  }

  /// Alias for [downloadProtectedMedia] (SEC-02).
  Future<Uint8List> getProtectedMediaBytes(String path) =>
      downloadProtectedMedia(path);

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

  /// On 401: try one shared refresh, retry the request once, else logout (SEC-05).
  Future<bool> _tryRefreshAndRetry(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final requestOptions = error.requestOptions;
    final failedAuthorization = requestOptions.headers['Authorization'];
    final currentToken = _accessToken;

    // Ignore unauthenticated calls
    if (failedAuthorization == null) {
      return false;
    }

    // If another concurrent request already refreshed the access token,
    // immediately retry this request using the fresh token without an extra refresh call.
    if (currentToken != null &&
        currentToken.isNotEmpty &&
        failedAuthorization != 'Bearer $currentToken') {
      return _retryWithToken(requestOptions, currentToken, handler);
    }

    // Session has no valid token
    if (currentToken == null || currentToken.isEmpty) {
      return false;
    }

    final outcome = await _refreshAccessTokenOnce();
    if (outcome == _RefreshOutcome.expired) {
      await _handleUnauthorized(requestOptions);
      return false;
    }
    if (outcome == _RefreshOutcome.transient) {
      // Keep the session: a network/5xx failure must not wipe refresh tokens.
      return false;
    }

    final newToken = _accessToken;
    if (newToken == null || newToken.isEmpty) {
      return false;
    }

    return _retryWithToken(requestOptions, newToken, handler);
  }

  Future<bool> _retryWithToken(
    RequestOptions requestOptions,
    String token,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final headers = Map<String, dynamic>.from(requestOptions.headers);
      headers['Authorization'] = 'Bearer $token';

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
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _handleUnauthorized(requestOptions);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Single-flight refresh used by the 401 interceptor.
  ///
  /// No token rotation: only access is updated. Returns an outcome instead of
  /// clearing tokens here, so a transient network/5xx failure keeps the
  /// session; only an explicit 401 triggers [_handleUnauthorized].
  Future<_RefreshOutcome> _refreshAccessTokenOnce() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    late final Future<_RefreshOutcome> operation;
    operation = _performAccessTokenRefresh().whenComplete(() {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
      }
    });
    _refreshInFlight = operation;
    return operation;
  }

  Future<_RefreshOutcome> _performAccessTokenRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return _RefreshOutcome.expired;
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
        // A malformed 200 response is a server problem, not proof of expiry.
        return _RefreshOutcome.transient;
      }
      // No rotation — never overwrite the stored refresh token here.
      await saveAccessToken(token);
      return _RefreshOutcome.success;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        return _RefreshOutcome.expired;
      }
      return _RefreshOutcome.transient;
    } catch (_) {
      return _RefreshOutcome.transient;
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
