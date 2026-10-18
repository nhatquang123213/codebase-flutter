import 'package:codebase_flutter/core/events/app_event.dart';
import 'package:codebase_flutter/core/events/app_events.dart';
import 'package:codebase_flutter/core/events/event_bus.dart';
import 'package:flutter_test/flutter_test.dart';

final class _OrderUpdated extends AppEvent {
  const _OrderUpdated(this.id);

  final String id;
}

void main() {
  late AppEventBus bus;

  setUp(() => bus = AppEventBus());
  tearDown(() => bus.dispose());

  test('on<T> delivers only events of that type', () async {
    final orders = <_OrderUpdated>[];
    final all = <AppEvent>[];
    bus.on<_OrderUpdated>().listen(orders.add);
    bus.on<AppEvent>().listen(all.add);

    bus
      ..fire(const SessionExpired())
      ..fire(const _OrderUpdated('1'))
      ..fire(const ConnectivityChanged(isOnline: false));
    await Future<void>.delayed(Duration.zero);

    expect(orders.map((e) => e.id), ['1']);
    expect(all, hasLength(3));
  });

  test('fire after dispose is ignored', () async {
    await bus.dispose();
    expect(() => bus.fire(const SessionExpired()), returnsNormally);
    bus = AppEventBus(); // so tearDown has something to dispose
  });
}
