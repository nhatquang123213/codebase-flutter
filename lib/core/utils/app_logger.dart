import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../monitoring/crash_reporter.dart';

/// Single logging entry point — never use `print`.
///
/// Console output is silent in release builds. [error] additionally goes to
/// [reporter] (Crashlytics in production) with the message as reason.
abstract final class AppLogger {
  /// Set once in `bootstrap`; stays a no-op when Firebase is not configured.
  static CrashReporter reporter = const NoopCrashReporter();

  static void debug(String message) => _log(message, level: 500);

  static void info(String message) => _log(message, level: 800);

  static void warning(String message) => _log(message, level: 900);

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(message, level: 1000, error: error, stackTrace: stackTrace);
    unawaited(
      reporter.recordError(error ?? message, stackTrace, reason: message),
    );
  }

  static void _log(
    String message, {
    required int level,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kReleaseMode) return;
    developer.log(
      message,
      name: 'APP',
      level: level,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
