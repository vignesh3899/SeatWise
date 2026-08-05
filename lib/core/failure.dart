import 'package:equatable/equatable.dart';

/// Base type for all recoverable errors surfaced to the presentation layer.
///
/// Repositories and services translate low-level exceptions (network, Firebase,
/// parsing) into a [Failure] so the UI can render a friendly message without
/// caring about the underlying cause.
sealed class Failure extends Equatable {
  const Failure(this.message);

  /// Human-readable, UI-safe message.
  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => '$runtimeType($message)';
}

/// The device (or a remote service) had no usable network connection.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

/// A remote API returned an error status or malformed body.
class ApiFailure extends Failure {
  const ApiFailure(super.message, {this.statusCode});

  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

/// Authentication-related failure (sign in / sign up / session).
class AuthFailure extends Failure {
  const AuthFailure(super.message, {this.code});

  /// Firebase error code, useful for analytics and localisation.
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

/// A Firestore / Storage read or write failed.
class DatabaseFailure extends Failure {
  const DatabaseFailure([super.message = 'Could not reach the database.']);
}

/// Input validation failed before a request was made.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// The requested computation could not be completed (e.g. empty route).
class EngineFailure extends Failure {
  const EngineFailure(super.message);
}

/// Anything that does not fit the categories above.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Something went wrong.']);
}
