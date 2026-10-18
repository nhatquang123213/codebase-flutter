import 'dart:async';

import '../utils/app_logger.dart';
import 'local_notification_service.dart';
import 'notification_payload.dart';
import 'push_notification_service.dart';

/// Glues FCM and local notifications together and exposes a single stream of
/// "the user tapped a notification" events for the app shell to navigate on.
///
/// Lifecycle: created once by DI, [start] is called from `App.initState`,
/// [dispose] from `App.dispose`.
class NotificationHandler {
  NotificationHandler({
    required PushNotificationService push,
    required LocalNotificationService local,
  }) : _push = push,
       _local = local;

  final PushNotificationService _push;
  final LocalNotificationService _local;
  final StreamController<NotificationPayload> _taps =
      StreamController<NotificationPayload>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _started = false;

  /// Emits the payload of every notification the user tapped, including the
  /// one that launched the app from a terminated state.
  Stream<NotificationPayload> get onTap => _taps.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _subscriptions
      ..add(_push.onForegroundMessage.listen(_onForegroundMessage))
      ..add(_push.onMessageOpenedApp.listen(_taps.add))
      ..add(_local.onTap.listen(_taps.add));

    // Terminated → launched by a tap. Emitted after listeners had a chance
    // to subscribe, so the router can act on it.
    final initial =
        await _push.getInitialMessage() ?? await _local.getLaunchPayload();
    if (initial != null) _taps.add(initial);
  }

  Future<void> _onForegroundMessage(NotificationPayload payload) async {
    AppLogger.debug('Foreground message ${payload.id}: ${payload.data}');
    await _local.show(payload);
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _taps.close();
  }
}
