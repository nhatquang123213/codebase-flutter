import 'dart:async';

import 'package:flutter/widgets.dart';

import '../events/app_events.dart';
import '../events/event_bus.dart';
import 'realtime_client.dart';

/// Ties the realtime connection to the session: connected while signed in,
/// closed on logout, nudged to reconnect when the network comes back or the
/// app returns to the foreground. Takes a `Stream<bool>` rather than
/// `AuthBloc` so core stays independent of features.
class RealtimeSession {
  RealtimeSession({
    required RealtimeClient client,
    required AppEventBus eventBus,
  }) : _client = client,
       _eventBus = eventBus;

  final RealtimeClient _client;
  final AppEventBus _eventBus;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  AppLifecycleListener? _lifecycle;

  void start({required bool initial, required Stream<bool> isAuthenticated}) {
    _subscriptions
      ..add(isAuthenticated.distinct().listen(_onAuthChanged))
      ..add(
        _eventBus.on<ConnectivityChanged>().listen((event) {
          if (event.isOnline) _client.retryNow();
        }),
      );
    _lifecycle = AppLifecycleListener(onResume: _client.retryNow);
    _onAuthChanged(initial);
  }

  void _onAuthChanged(bool authenticated) =>
      unawaited(authenticated ? _client.connect() : _client.disconnect());

  Future<void> dispose() async {
    _lifecycle?.dispose();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _client.disconnect();
  }
}
