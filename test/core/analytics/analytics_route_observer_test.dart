import 'package:codebase_flutter/core/analytics/analytics.dart';
import 'package:codebase_flutter/core/analytics/analytics_route_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAnalytics extends NoopAnalytics {
  const _RecordingAnalytics(this.screens);

  final List<String> screens;

  @override
  Future<void> logScreenView(String screenName) async =>
      screens.add(screenName);
}

void main() {
  late List<String> screens;
  late AnalyticsRouteObserver observer;

  setUp(() {
    screens = [];
    observer = AnalyticsRouteObserver(_RecordingAnalytics(screens));
  });

  Route<void> page(String name) => MaterialPageRoute<void>(
    settings: RouteSettings(name: name),
    builder: (_) => const SizedBox(),
  );

  test('logs pushes, pops (previous route) and skips duplicates', () {
    final home = page('/');
    final details = page('/details');

    observer
      ..didPush(home, null)
      ..didPush(details, home)
      ..didPush(details, home) // e.g. a rebuild re-reporting the same page
      ..didPop(details, home);

    expect(screens, ['/', '/details', '/']);
  });

  test('ignores dialogs and unnamed routes', () {
    observer
      ..didPush(page('/'), null)
      ..didPush(
        RawDialogRoute<void>(
          pageBuilder: (_, _, _) => const SizedBox(),
          settings: const RouteSettings(name: '/dialog'),
        ),
        null,
      )
      ..didPush(page(''), null);

    expect(screens, ['/']);
  });
}
