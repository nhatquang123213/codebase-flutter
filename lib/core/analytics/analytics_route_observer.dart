import 'dart:async';

import 'package:flutter/widgets.dart';

import 'analytics.dart';

/// Logs a screen view for every page route. go_router names pages after
/// their path (or `name:` when set), so dashboards show `/login`, `/`, ...
///
/// Install on the root router; a `ShellRoute` has its own navigator and needs
/// its own instance in `observers:`.
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver(this._analytics);

  final Analytics _analytics;
  String? _lastScreen;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _track(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(previousRoute);

  void _track(Route<dynamic>? route) {
    // Dialogs and bottom sheets are PopupRoutes — not screens.
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name == null || name.isEmpty || name == _lastScreen) return;
    _lastScreen = name;
    unawaited(_analytics.logScreenView(name));
  }
}
