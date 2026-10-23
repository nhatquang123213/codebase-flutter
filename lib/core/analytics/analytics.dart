import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';

/// Product analytics. Features depend on this interface, never on the
/// Firebase SDK, so the vendor can change without touching call sites.
///
/// Event and parameter names: snake_case, ≤ 40 chars, see [AnalyticsEvents].
abstract interface class Analytics {
  Future<void> logEvent(String name, {Map<String, Object>? parameters});

  Future<void> logScreenView(String screenName);

  Future<void> logLogin({String method = 'password'});

  /// Pass null on logout.
  Future<void> setUserId(String? userId);

  Future<void> setUserProperty(String name, String? value);
}

/// Names shared by the app and whoever reads the dashboards.
abstract final class AnalyticsEvents {
  static const String login = 'login';
  static const String logout = 'logout';
}

class FirebaseAnalyticsService implements Analytics {
  FirebaseAnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  /// Debug sessions would pollute production funnels.
  Future<void> init() => _analytics.setAnalyticsCollectionEnabled(!kDebugMode);

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) =>
      _analytics.logEvent(name: name, parameters: parameters);

  @override
  Future<void> logScreenView(String screenName) =>
      _analytics.logScreenView(screenName: screenName);

  @override
  Future<void> logLogin({String method = 'password'}) =>
      _analytics.logLogin(loginMethod: method);

  @override
  Future<void> setUserId(String? userId) => _analytics.setUserId(id: userId);

  @override
  Future<void> setUserProperty(String name, String? value) =>
      _analytics.setUserProperty(name: name, value: value);
}

/// Used when Firebase is not configured; logs so events are still visible
/// while developing.
class NoopAnalytics implements Analytics {
  const NoopAnalytics();

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    AppLogger.debug('Analytics: $name ${parameters ?? ''}');
  }

  @override
  Future<void> logScreenView(String screenName) async {
    AppLogger.debug('Analytics: screen $screenName');
  }

  @override
  Future<void> logLogin({String method = 'password'}) =>
      logEvent(AnalyticsEvents.login, parameters: {'method': method});

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {}
}
