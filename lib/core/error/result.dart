import 'app_failure.dart';

/// Monadic Result type representing either a [Success] with value [T]
/// or a [FailureResult] with [AppFailure].
sealed class Result<T> {
  const Result();

  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(AppFailure failure) = FailureResult<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  T? get dataOrNull => switch (this) {
    Success(:final data) => data,
    _ => null,
  };

  AppFailure? get failureOrNull => switch (this) {
    FailureResult(:final failure) => failure,
    _ => null,
  };

  R when<R>({
    required R Function(T data) onSuccess,
    required R Function(AppFailure failure) onFailure,
  }) => switch (this) {
    Success(:final data) => onSuccess(data),
    FailureResult(:final failure) => onFailure(failure),
  };

  R fold<R>(
    R Function(AppFailure failure) onFailure,
    R Function(T data) onSuccess,
  ) => switch (this) {
    Success(:final data) => onSuccess(data),
    FailureResult(:final failure) => onFailure(failure),
  };

  Result<R> map<R>(R Function(T data) transform) => switch (this) {
    Success(:final data) => Result.success(transform(data)),
    FailureResult(:final failure) => Result.failure(failure),
  };

  Result<R> flatMap<R>(Result<R> Function(T data) transform) => switch (this) {
    Success(:final data) => transform(data),
    FailureResult(:final failure) => Result.failure(failure),
  };

  T getOrThrow() => switch (this) {
    Success(:final data) => data,
    FailureResult(:final failure) => throw failure,
  };
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Success($data)';
}

final class FailureResult<T> extends Result<T> {
  final AppFailure failure;
  const FailureResult(this.failure);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FailureResult<T> &&
          runtimeType == other.runtimeType &&
          failure == other.failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'FailureResult($failure)';
}
