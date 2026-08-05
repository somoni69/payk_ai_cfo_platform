import 'dart:async';

import 'package:dio/dio.dart';

/// Stable localization keys for infrastructure and feature failures.
///
/// UI must resolve these via [LanguageCubit.translate] /
/// [LanguageCubit.translateMessage]. Raw response bodies, URLs, tokens and
/// stack traces stay out of UI.
abstract final class ErrorKeys {
  static const timeout = 'error_timeout';
  static const offline = 'error_offline';
  static const cancelled = 'error_cancelled';
  static const badCertificate = 'error_bad_certificate';
  static const sessionExpired = 'error_session_expired';
  static const forbidden = 'error_forbidden';
  static const conflict = 'error_conflict';
  static const validation = 'error_validation';
  static const rateLimited = 'error_rate_limited';
  static const server = 'error_server';
  static const generic = 'error_generic';
  static const loadFailed = 'error_load_failed';
  static const saveFailed = 'error_save_failed';
  static const invalidId = 'error_invalid_id';
  static const invalidResponse = 'error_invalid_response';
  static const noResource = 'error_no_resource';
  static const loginInvalid = 'error_login_invalid';
  static const loginForbidden = 'error_login_forbidden';
  static const loginValidation = 'error_login_validation';
  static const loginRateLimited = 'error_login_rate_limited';
  static const loginUnavailable = 'error_login_unavailable';
  static const loginFailed = 'error_login_failed';
  static const twoFactorInvalid = 'error_two_factor_invalid';
  static const twoFactorValidation = 'error_two_factor_validation';
  static const twoFactorFailed = 'error_two_factor_failed';
  static const biometricsUnavailable = 'error_biometrics_unavailable';
  static const biometricsNoSession = 'error_biometrics_no_session';
  static const biometricsFailed = 'error_biometrics_failed';
  static const biometricsError = 'error_biometrics_error';
}

/// Converts infrastructure failures into localization keys safe for UI.
String userFacingError(Object error, {String fallback = ErrorKeys.generic}) {
  if (error is TimeoutException) {
    return ErrorKeys.timeout;
  }

  if (error is! DioException) return fallback;

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return ErrorKeys.timeout;
    case DioExceptionType.connectionError:
      return ErrorKeys.offline;
    case DioExceptionType.cancel:
      return ErrorKeys.cancelled;
    case DioExceptionType.badCertificate:
      return ErrorKeys.badCertificate;
    case DioExceptionType.badResponse:
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        return ErrorKeys.sessionExpired;
      }
      if (statusCode == 403) {
        return ErrorKeys.forbidden;
      }
      if (statusCode == 409) {
        return ErrorKeys.conflict;
      }
      if (statusCode == 422) {
        return ErrorKeys.validation;
      }
      if (statusCode == 429) {
        return ErrorKeys.rateLimited;
      }
      if (statusCode != null && statusCode >= 500) {
        return ErrorKeys.server;
      }
      return fallback;
    case DioExceptionType.unknown:
      return fallback;
  }
}

/// Wraps a repository call so Dio/transport failures become stable error keys.
Future<T> mapRepositoryError<T>(
  Future<T> Function() action, {
  String fallback = ErrorKeys.loadFailed,
}) async {
  try {
    return await action();
  } catch (error) {
    throw Exception(userFacingError(error, fallback: fallback));
  }
}
