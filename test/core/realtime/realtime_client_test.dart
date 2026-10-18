import 'package:codebase_flutter/core/events/app_events.dart';
import 'package:codebase_flutter/core/events/event_bus.dart';
import 'package:codebase_flutter/core/realtime/realtime_client.dart';
import 'package:codebase_flutter/core/realtime/realtime_message.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_realtime_transport.dart';

void main() {
  const backoff = RealtimeBackoff(
    initial: Duration(seconds: 1),
    max: Duration(seconds: 4),
    jitter: Duration.zero,
  );
  const heartbeat = Duration(seconds: 10);

  late FakeRealtimeTransport transport;
  late AppEventBus bus;
  late WebSocketRealtimeClient client;
  late List<RealtimeStatus> statuses;
  late List<RealtimeMessageReceived> received;
  const token = 'tok';

  setUp(() {
    transport = FakeRealtimeTransport();
    bus = AppEventBus();
    statuses = [];
    received = [];
    bus.on<RealtimeMessageReceived>().listen(received.add);
    client = WebSocketRealtimeClient(
      transport: transport,
      uri: Uri.parse('wss://api.test/ws'),
      tokenProvider: () async => token,
      eventBus: bus,
      backoff: backoff,
      heartbeatInterval: heartbeat,
    );
    client.onStatusChanged.listen(statuses.add);
  });

  tearDown(() async {
    await client.dispose();
    await bus.dispose();
  });

  test('connects with bearer token and forwards messages to the bus', () {
    fakeAsync((async) {
      client.connect();
      async.flushMicrotasks();

      expect(transport.headers.single['Authorization'], 'Bearer tok');
      expect(client.status, RealtimeStatus.connected);

      transport.last.receive('{"type":"order.updated","data":{"id":"7"}}');
      transport.last.receive('{"type":"pong"}');
      transport.last.receive('not json');
      async.flushMicrotasks();

      expect(received.map((e) => e.message), [
        const RealtimeMessage(type: 'order.updated', data: {'id': '7'}),
      ]);
    });
  });

  test('reconnects with exponential backoff after the server drops', () {
    fakeAsync((async) {
      client.connect();
      async.flushMicrotasks();
      transport.failNext = 2; // next two attempts fail → 1s, 2s delays
      transport.last.drop();
      async.flushMicrotasks();

      expect(client.status, RealtimeStatus.reconnecting);
      expect(transport.connectCalls, 1);

      async.elapse(const Duration(seconds: 1));
      expect(transport.connectCalls, 2); // failed
      async.elapse(const Duration(seconds: 2));
      expect(transport.connectCalls, 3); // failed
      async.elapse(const Duration(seconds: 4));
      expect(transport.connectCalls, 4); // capped at max, succeeds
      expect(client.status, RealtimeStatus.connected);
    });
  });

  test('retryNow skips the pending delay', () {
    fakeAsync((async) {
      transport.failNext = 1;
      client.connect();
      async.flushMicrotasks();
      expect(client.status, RealtimeStatus.reconnecting);

      client.retryNow();
      async.flushMicrotasks();

      expect(transport.connectCalls, 2);
      expect(client.status, RealtimeStatus.connected);
    });
  });

  test('disconnect stops reconnecting and closes the socket', () {
    fakeAsync((async) {
      client.connect();
      async.flushMicrotasks();
      final connection = transport.last;

      client.disconnect();
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 1));

      expect(connection.closed, isTrue);
      expect(transport.connectCalls, 1);
      expect(client.status, RealtimeStatus.disconnected);
    });
  });

  test('sends pings and reconnects when the socket goes silent', () {
    fakeAsync((async) {
      client.connect();
      async.flushMicrotasks();

      async.elapse(heartbeat);
      expect(transport.last.sent, [RealtimeMessage.ping.encode()]);

      // Nothing inbound for > 2 intervals → considered dead.
      async.elapse(heartbeat * 2);
      async.flushMicrotasks();
      expect(transport.connections.first.closed, isTrue);
      async.elapse(backoff.initial);
      expect(transport.connectCalls, 2);
      expect(client.status, RealtimeStatus.connected);
    });
  });

  test('status stream reports the lifecycle', () {
    fakeAsync((async) {
      client.connect();
      async.flushMicrotasks();
      transport.last.drop();
      async.flushMicrotasks();
      async.elapse(backoff.initial);
      client.disconnect();
      async.flushMicrotasks();

      expect(statuses, [
        RealtimeStatus.connecting,
        RealtimeStatus.connected,
        RealtimeStatus.reconnecting,
        RealtimeStatus.connected,
        RealtimeStatus.disconnected,
      ]);
    });
  });
}
