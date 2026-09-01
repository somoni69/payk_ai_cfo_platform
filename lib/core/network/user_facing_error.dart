import 'dart:async';

import 'package:dio/dio.dart';
import '../error/app_failure.dart';
import '../error/result.dart';

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

/// Maps any caught error or exception into a typed [AppFailure].
AppFailure mapExceptionToFailure(
  Object error, {
  String fallback = ErrorKeys.generic,
  StackTrace? stackTrace,
}) {
  if (error is AppFailure) {
    return error;
  }

  if (error is TimeoutException) {
    return TimeoutFailure(debugMessage: error.message, stackTrace: stackTrace);
  }

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutFailure(
          debugMessage: error.message,
          stackTrace: stackTrace ?? error.stackTrace,
        );
      case DioExceptionType.connectionError:
        return NetworkFailure(
          debugMessage: error.message,
          stackTrace: stackTrace ?? error.stackTrace,
        );
      case DioExceptionType.cancel:
        return GenericFailure(
          translationKey: ErrorKeys.cancelled,
          debugMessage: error.message,
          stackTrace: stackTrace ?? error.stackTrace,
        );
      case DioExceptionType.badCertificate:
        return GenericFailure(
          translationKey: ErrorKeys.badCertificate,
          debugMessage: error.message,
          stackTrace: stackTrace ?? error.stackTrace,
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          return AuthFailure(
            translationKey: ErrorKeys.sessionExpired,
            debugMessage: error.message,
            stackTrace: stackTrace ?? error.stackTrace,
          );
        }
        if (statusCode == 403) {
          return AuthFailure(
            translationKey: ErrorKeys.forbidden,
            debugMessage: error.message,
            stackTrace: stackTrace ?? error.stackTrace,
          );
        }
        if (statusCode == 404) {
          return NotFoundFailure(
            debugMessage: error.message,
            stackTrace: stackTrace ?? error.stackTrace,
          );
        }
        if (statusCode == 409) {
          return ServerFailure(
            translationKey: ErrorKeys.conflict,
            statusCode: 409,
            debugMessage: error.message,
            stackTrace: stackTrace ?? error.stackTrace,
          );
        }
        if (statusCode == 422) {
          return ValidationFailure(
            debugMessage: error.message,
            stackTrace: stackTrace ?? error.stackTrace,
          );
        }
        if (statusCode == 429) {
          return ServerFailure(
            translationKey: ErrorKeys.rateLimited,
            statusCode: 429,
            debugMessage: error.message,
            stackTrace: stackTrace ?? error.stackTrace,
          );
        }
        if (statusCode != null && statusCode >= 500) {
          return ServerFailure(
            statusCode: statusCode,
            debugMessage: error.message,
            stackTrace: stackTrace ?? error.stackTrace,
          );
        }
        return ServerFailure(
          translationKey: fallback,
          statusCode: statusCode,
          debugMessage: error.message,
          stackTrace: stackTrace ?? error.stackTrace,
        );
      case DioExceptionType.unknown:
        return GenericFailure(
          translationKey: fallback,
          debugMessage: error.message,
          stackTrace: stackTrace ?? error.stackTrace,
        );
    }
  }

  return GenericFailure(
    translationKey: fallback,
    debugMessage: error.toString(),
    stackTrace: stackTrace,
  );
}

/// Converts infrastructure failures into localization keys safe for UI.
String userFacingError(Object error, {String fallback = ErrorKeys.generic}) {
  if (error is AppFailure) {
    return error.translationKey;
  }
  return mapExceptionToFailure(error, fallback: fallback).translationKey;
}

/// Wraps a repository call so failures become typed [AppFailure] instances.
Future<T> mapRepositoryError<T>(
  Future<T> Function() action, {
  String fallback = ErrorKeys.loadFailed,
}) async {
  try {
    return await action();
  } catch (error, stackTrace) {
    throw mapExceptionToFailure(
      error,
      fallback: fallback,
      stackTrace: stackTrace,
    );
  }
}

/// Executes an async action safely returning a monadic [Result<T>].
Future<Result<T>> runCatchingAsync<T>(
  Future<T> Function() action, {
  String fallback = ErrorKeys.loadFailed,
}) async {
  try {
    final data = await action();
    return Result.success(data);
  } catch (error, stackTrace) {
    return Result.failure(
      mapExceptionToFailure(error, fallback: fallback, stackTrace: stackTrace),
    );
  }
}
