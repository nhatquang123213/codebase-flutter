import 'package:codebase_flutter/core/notifications/local_notification_service.dart';
import 'package:codebase_flutter/core/notifications/notification_handler.dart';
import 'package:codebase_flutter/core/notifications/notification_payload.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_push_notification_service.dart';

class _MockLocal extends Mock implements LocalNotificationService {}

void main() {
  const payload = NotificationPayload(id: 'm1', title: 't', body: 'b');

  late FakePushNotificationService push;
  late _MockLocal local;
  late NotificationHandler handler;

  setUpAll(() => registerFallbackValue(const NotificationPayload()));

  setUp(() {
    push = FakePushNotificationService();
    local = _MockLocal();
    when(() => local.onTap).thenAnswer((_) => const Stream.empty());
    when(() => local.getLaunchPayload()).thenAnswer((_) async => null);
    when(() => local.show(any())).thenAnswer((_) async {});
    handler = NotificationHandler(push: push, local: local);
  });

  tearDown(() async {
    await handler.dispose();
    await push.dispose();
  });

  test('foreground messages are shown as local notifications', () async {
    await handler.start();
    push.foreground.add(payload);
    await Future<void>.delayed(Duration.zero);
    verify(() => local.show(payload)).called(1);
  });

  test('background taps are forwarded to onTap', () async {
    await handler.start();
    final taps = <NotificationPayload>[];
    handler.onTap.listen(taps.add);

    push.opened.add(payload);
    await Future<void>.delayed(Duration.zero);

    expect(taps, [payload]);
  });

  test('the message that launched the app is emitted on start', () async {
    push.initialMessage = payload;
    final taps = <NotificationPayload>[];
    handler.onTap.listen(taps.add);

    await handler.start();
    await Future<void>.delayed(Duration.zero);

    expect(taps, [payload]);
  });
}
