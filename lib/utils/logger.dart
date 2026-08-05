import 'package:flutter/foundation.dart';

/// Minimal logging wrapper. In debug builds it prints to the console; in release
/// builds the messages are swallowed (real errors are reported via Crashlytics
/// in `main.dart`). Using this instead of `print` keeps the linter happy and
/// gives us a single choke point to change logging behaviour later.
class Log {
  Log._();

  static void d(String message, {String tag = 'SeatWise'}) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  static void e(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('[SeatWise][ERROR] $message ${error ?? ''}');
      if (stackTrace != null) debugPrint(stackTrace.toString());
    }
  }
}
