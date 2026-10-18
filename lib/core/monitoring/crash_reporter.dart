import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Where unexpected errors go in production. Features never import a crash
/// SDK directly; they call `AppLogger.error`, which forwards here.
abstract interface class CrashReporter {
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  });

  Future<void> recordFlutterError(FlutterErrorDetails details);

  /// Breadcrumb attached to the next report (not sent on its own).
  Future<void> log(String message);

  /// Pass null on logout.
  Future<void> setUserId(String? userId);
}

class CrashlyticsReporter implements CrashReporter {
  CrashlyticsReporter(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  /// Debug sessions would flood the dashboard with developer mistakes.
  Future<void> init() =>
      _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) =>
      _crashlytics.recordError(error, stackTrace, reason: reason, fatal: fatal);

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) =>
      _crashlytics.recordFlutterFatalError(details);

  @override
  Future<void> log(String message) => _crashlytics.log(message);

  @override
  Future<void> setUserId(String? userId) =>
      _crashlytics.setUserIdentifier(userId ?? '');
}

class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {}

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) async {}

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}
