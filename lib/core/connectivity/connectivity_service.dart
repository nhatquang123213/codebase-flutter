import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../events/app_events.dart';
import '../events/event_bus.dart';
import '../utils/app_logger.dart';

/// Whether the device has a network interface that can reach the internet.
///
/// "Online" means an interface is up, not that the backend is reachable —
/// requests can still fail with `NetworkFailure`. It is accurate enough to
/// fail fast and to show an offline banner.
abstract interface class ConnectivityService {
  bool get isOnline;

  /// Emits only on change; the current value is [isOnline].
  Stream<bool> get onStatusChanged;
}

class PlusConnectivityService implements ConnectivityService {
  PlusConnectivityService(this._connectivity, this._eventBus);

  final Connectivity _connectivity;
  final AppEventBus _eventBus;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onStatusChanged => _changes.stream;

  Future<void> init() async {
    try {
      _isOnline = _toOnline(await _connectivity.checkConnectivity());
    } catch (e) {
      // Some emulators/platforms throw; assume online rather than block the app.
      AppLogger.warning('Connectivity check failed: $e');
    }
    _subscription = _connectivity.onConnectivityChanged.listen(_onResults);
  }

  void _onResults(List<ConnectivityResult> results) {
    final online = _toOnline(results);
    if (online == _isOnline) return;
    _isOnline = online;
    AppLogger.info(online ? 'Back online' : 'Offline');
    _changes.add(online);
    _eventBus.fire(ConnectivityChanged(isOnline: online));
  }

  static bool _toOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }
}
