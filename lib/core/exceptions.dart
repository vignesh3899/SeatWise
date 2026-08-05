/// Exceptions thrown by the service layer. They are caught by repositories and
/// converted into typed [Failure]s. Keeping them separate keeps the low-level
/// networking code readable while the app never has to catch raw exceptions.

/// Thrown when an HTTP request to a free API fails or returns a non-2xx status.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thrown when there is no network connectivity.
class NoConnectionException implements Exception {
  NoConnectionException([this.message = 'No internet connection.']);
  final String message;

  @override
  String toString() => 'NoConnectionException: $message';
}

/// Thrown when a response body cannot be parsed into the expected shape.
class ParseException implements Exception {
  ParseException(this.message);
  final String message;

  @override
  String toString() => 'ParseException: $message';
}
