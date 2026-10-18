import 'dart:async';

import 'package:codebase_flutter/core/events/app_events.dart';
import 'package:codebase_flutter/core/events/event_bus.dart';
import 'package:codebase_flutter/core/realtime/realtime_client.dart';
import 'package:codebase_flutter/core/realtime/realtime_message.dart';
import 'package:codebase_flutter/core/realtime/realtime_session.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingClient implements RealtimeClient {
  final List<String> calls = [];

  @override
  RealtimeStatus get status => RealtimeStatus.disconnected;

  @override
  Stream<RealtimeStatus> get onStatusChanged => const Stream.empty();

  @override
  Future<void> connect() async => calls.add('connect');

  @override
  Future<void> disconnect() async => calls.add('disconnect');

  @override
  void retryNow() => calls.add('retryNow');

  @override
  void send(RealtimeMessage message) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingClient client;
  late AppEventBus bus;
  late StreamController<bool> auth;
  late RealtimeSession session;

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  setUp(() {
    client = _RecordingClient();
    bus = AppEventBus();
    auth = StreamController<bool>.broadcast();
    session = RealtimeSession(client: client, eventBus: bus);
  });

  tearDown(() async {
    await session.dispose();
    await auth.close();
    await bus.dispose();
  });

  test('connects while authenticated, disconnects on logout', () async {
    session.start(initial: false, isAuthenticated: auth.stream);
    await pump();
    expect(client.calls, ['disconnect']);

    auth.add(true);
    await pump();
    auth.add(true); // duplicate ignored
    await pump();
    auth.add(false);
    await pump();

    expect(client.calls, ['disconnect', 'connect', 'disconnect']);
  });

  test('retries when connectivity is restored', () async {
    session.start(initial: true, isAuthenticated: auth.stream);
    await pump();

    bus
      ..fire(const ConnectivityChanged(isOnline: false))
      ..fire(const ConnectivityChanged(isOnline: true));
    await pump();

    expect(client.calls, ['connect', 'retryNow']);
  });
}
