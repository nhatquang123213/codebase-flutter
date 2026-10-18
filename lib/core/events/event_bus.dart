import 'dart:async';

import '../utils/app_logger.dart';
import 'app_event.dart';

/// In-process pub/sub for things that cross feature boundaries
/// (session expiry, connectivity, realtime messages, ...).
///
/// Use it when the producer must not know the consumer. For state that a
/// widget renders, keep using a bloc; for a direct dependency, inject it.
///
/// ```dart
/// _sub = eventBus.on<OrderUpdated>().listen((e) => add(OrderRefreshed(e.id)));
/// ```
class AppEventBus {
  final StreamController<AppEvent> _controller =
      StreamController<AppEvent>.broadcast();

  /// Events of type [T] (and subtypes). Remember to cancel the subscription.
  Stream<T> on<T extends AppEvent>() =>
      _controller.stream.where((event) => event is T).cast<T>();

  void fire(AppEvent event) {
    if (_controller.isClosed) return;
    AppLogger.debug('Event: $event');
    _controller.add(event);
  }

  Future<void> dispose() => _controller.close();
}
