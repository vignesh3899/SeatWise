import 'failure.dart';

/// A lightweight functional result type used across repositories and services
/// so that error handling is explicit and does not rely on throwing.
sealed class Result<T> {
  const Result();

  /// Whether this result holds a value.
  bool get isSuccess => this is Success<T>;

  /// Whether this result holds a [Failure].
  bool get isFailure => this is ResultFailure<T>;

  /// Returns the value or `null` if this is a failure.
  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        ResultFailure<T>() => null,
      };

  /// Returns the [Failure] or `null` if this is a success.
  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        ResultFailure<T>(:final failure) => failure,
      };

  /// Folds both branches into a single value of type [R].
  R when<R>({
  required R Function(T value) onSuccess,
  required R Function(Failure error) onFailure,
}) {
  return switch (this) {
    Success<T>(:final value) => onSuccess(value),
    ResultFailure<T>(:final failure) => onFailure(failure),
  };
}

  /// Maps the success value while preserving a failure.
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success<T>(:final value) => Success<R>(transform(value)),
      ResultFailure<T>(:final failure) => ResultFailure<R>(failure),
    };
  }
}

/// Successful result carrying a [value].
class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

/// Failed result carrying a [Failure].
class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.failure);
  final Failure failure;
}
