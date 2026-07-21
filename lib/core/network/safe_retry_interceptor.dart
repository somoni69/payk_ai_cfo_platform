import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

typedef RetryDelay = Future<void> Function(Duration duration);
typedef RequestSessionValidator = bool Function(RequestOptions options);

/// Retries only idempotent reads after transient transport/server failures.
///
/// Mutating requests are deliberately excluded: POST/PATCH/DELETE retries are
/// safe only after the backend supports idempotency keys.
class SafeRetryInterceptor extends Interceptor {
  SafeRetryInterceptor({
    required this.dio,
    this.maxRetries = 2,
    RetryDelay? delay,
    this.isSessionCurrent,
    Random? random,
  }) : _delay = delay ?? Future<void>.delayed,
       _random = random ?? Random();

  static const _attemptKey = 'safe_retry_attempt';
  static const _retryableMethods = {'GET', 'HEAD', 'OPTIONS'};
  static const _retryableStatusCodes = {429, 502, 503, 504};

  final Dio dio;
  final int maxRetries;
  final RetryDelay _delay;
  final RequestSessionValidator? isSessionCurrent;
  final Random _random;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final attempt = request.extra[_attemptKey] as int? ?? 0;

    if (attempt >= maxRetries ||
        !_retryableMethods.contains(request.method.toUpperCase()) ||
        !_isTransient(err) ||
        !(isSessionCurrent?.call(request) ?? true)) {
      handler.next(err);
      return;
    }

    final retryAfter = _retryAfter(err.response);
    final backoff = Duration(
      milliseconds: 300 * (1 << attempt) + _random.nextInt(151),
    );
    await _delay(retryAfter ?? backoff);

    if (!(isSessionCurrent?.call(request) ?? true)) {
      handler.next(err);
      return;
    }

    final retryRequest = request.copyWith(
      extra: Map<String, dynamic>.of(request.extra)
        ..[_attemptKey] = attempt + 1,
    );

    try {
      final response = await dio.fetch<dynamic>(retryRequest);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _isTransient(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      return _retryableStatusCodes.contains(statusCode);
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      _ => false,
    };
  }

  Duration? _retryAfter(Response<dynamic>? response) {
    if (response?.statusCode != 429) return null;

    final raw = response?.headers.value('retry-after');
    final seconds = int.tryParse(raw ?? '');
    if (seconds == null || seconds < 0) return null;

    // Avoid keeping a foreground request suspended for an excessive server
    // value. The user can retry explicitly after the error is surfaced.
    return Duration(seconds: min(seconds, 5));
  }
}
