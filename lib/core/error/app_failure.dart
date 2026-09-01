import 'package:equatable/equatable.dart';
import '../network/user_facing_error.dart';

/// Typed sealed failure hierarchy for PAYK CFO platform.
///
/// Encapsulates localization translation keys and diagnostic metadata
/// without leaking sensitive tokens, raw payloads, or stack traces to UI.
sealed class AppFailure extends Equatable implements Exception {
  final String translationKey;
  final String? debugMessage;
  final StackTrace? stackTrace;

  const AppFailure(this.translationKey, {this.debugMessage, this.stackTrace});

  @override
  String toString() => translationKey;

  @override
  List<Object?> get props => [translationKey, debugMessage];
}

/// Network transport and offline connectivity failures.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    String translationKey = ErrorKeys.offline,
    super.debugMessage,
    super.stackTrace,
  }) : super(translationKey);
}

/// HTTP and API backend failures.
final class ServerFailure extends AppFailure {
  final int? statusCode;

  const ServerFailure({
    String translationKey = ErrorKeys.server,
    this.statusCode,
    super.debugMessage,
    super.stackTrace,
  }) : super(translationKey);

  @override
  List<Object?> get props => [translationKey, statusCode, debugMessage];
}

/// Authentication and authorization failures (401, 403, 2FA, biometrics).
final class AuthFailure extends AppFailure {
  const AuthFailure({
    String translationKey = ErrorKeys.sessionExpired,
    super.debugMessage,
    super.stackTrace,
  }) : super(translationKey);
}

/// Validation and unprocessable entity errors (422).
final class ValidationFailure extends AppFailure {
  final Map<String, List<String>> fieldErrors;

  const ValidationFailure({
    String translationKey = ErrorKeys.validation,
    this.fieldErrors = const {},
    super.debugMessage,
    super.stackTrace,
  }) : super(translationKey);

  @override
  List<Object?> get props => [translationKey, fieldErrors, debugMessage];
}

/// Request timeout failures (connection, send, receive timeout).
final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({
    String translationKey = ErrorKeys.timeout,
    super.debugMessage,
    super.stackTrace,
  }) : super(translationKey);
}

/// Resource not found (404).
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({
    String translationKey = ErrorKeys.noResource,
    super.debugMessage,
    super.stackTrace,
  }) : super(translationKey);
}

/// Local cache / persistence failures.
final class CacheFailure extends AppFailure {
  const CacheFailure({
    String translationKey = ErrorKeys.loadFailed,
    super.debugMessage,
    super.stackTrace,
  }) : super(translationKey);
}

/// Fallback / unknown generic application failures.
final class GenericFailure extends AppFailure {
  const GenericFailure({
    String translationKey = ErrorKeys.generic,
    super.debugMessage,
    super.stackTrace,
  }) : super(translationKey);
}
