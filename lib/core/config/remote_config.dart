import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';

/// Every remote config key the app reads, with the value used until the first
/// successful fetch (and forever when Firebase is not configured).
///
/// Keep this list in sync with the Firebase console; an unknown key silently
/// returns the type's zero value.
abstract final class RemoteConfigKeys {
  /// Builds older than this are blocked (see `features/app_update`).
  static const String minSupportedVersion = 'min_supported_version';

  /// Builds older than this get a dismissible "update available" prompt.
  static const String latestVersion = 'latest_version';
  static const String storeUrlAndroid = 'store_url_android';
  static const String storeUrlIos = 'store_url_ios';

  /// Example feature flag — copy this pattern for real ones (see `FeatureFlags`).
  static const String exampleFeatureEnabled = 'example_feature_enabled';

  static const Map<String, Object> defaults = {
    minSupportedVersion: '0.0.0',
    latestVersion: '0.0.0',
    storeUrlAndroid: '',
    storeUrlIos: '',
    exampleFeatureEnabled: false,
  };
}

/// Read-only view of remote configuration. Values are always available
/// synchronously: defaults first, last fetched values once activated.
abstract interface class RemoteConfigService {
  /// Applies defaults and whatever was fetched last session, then starts a
  /// background fetch. Never throws and never waits for the network.
  Future<void> init();

  String getString(String key);
  bool getBool(String key);
  int getInt(String key);
  double getDouble(String key);

  /// Fires after new values have been activated (background fetch or
  /// realtime push). Listeners re-read the keys they care about.
  Stream<void> get onUpdated;

  /// Forces a fetch + activate. Returns true when values changed.
  Future<bool> refresh();

  Future<void> dispose();
}

class FirebaseRemoteConfigService implements RemoteConfigService {
  FirebaseRemoteConfigService(this._remoteConfig);

  final FirebaseRemoteConfig _remoteConfig;
  final StreamController<void> _updated = StreamController<void>.broadcast();
  StreamSubscription<RemoteConfigUpdate>? _realtime;

  static const Duration _fetchTimeout = Duration(seconds: 10);

  @override
  Future<void> init() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: _fetchTimeout,
          // Debug builds always fetch so flags can be flipped while developing;
          // release builds respect Firebase's recommended throttle.
          minimumFetchInterval: kDebugMode
              ? Duration.zero
              : const Duration(hours: 1),
        ),
      );
      await _remoteConfig.setDefaults(RemoteConfigKeys.defaults);
      await _remoteConfig.activate();
    } catch (e, st) {
      AppLogger.error('Remote config init failed', e, st);
    }
    _realtime = _remoteConfig.onConfigUpdated.listen((_) async {
      await _remoteConfig.activate();
      _notify();
    }, onError: (Object e) => AppLogger.warning('Remote config realtime: $e'));
    unawaited(refresh());
  }

  @override
  Future<bool> refresh() async {
    try {
      final changed = await _remoteConfig.fetchAndActivate();
      if (changed) _notify();
      return changed;
    } catch (e) {
      // Offline / throttled — keep serving the last activated values.
      AppLogger.warning('Remote config fetch failed: $e');
      return false;
    }
  }

  void _notify() {
    AppLogger.info('Remote config updated');
    if (!_updated.isClosed) _updated.add(null);
  }

  @override
  String getString(String key) => _remoteConfig.getString(key);

  @override
  bool getBool(String key) => _remoteConfig.getBool(key);

  @override
  int getInt(String key) => _remoteConfig.getInt(key);

  @override
  double getDouble(String key) => _remoteConfig.getDouble(key);

  @override
  Stream<void> get onUpdated => _updated.stream;

  @override
  Future<void> dispose() async {
    await _realtime?.cancel();
    await _updated.close();
  }
}

/// Serves [RemoteConfigKeys.defaults] (plus anything passed to [update]).
/// Used when Firebase is not configured and as the test double.
class InMemoryRemoteConfigService implements RemoteConfigService {
  InMemoryRemoteConfigService([Map<String, Object> overrides = const {}])
    : _values = {...RemoteConfigKeys.defaults, ...overrides};

  final Map<String, Object> _values;
  final StreamController<void> _updated = StreamController<void>.broadcast();

  @override
  Future<void> init() async {}

  /// Simulates a fetch: merges [values] and notifies listeners.
  void update(Map<String, Object> values) {
    _values.addAll(values);
    if (!_updated.isClosed) _updated.add(null);
  }

  @override
  String getString(String key) => _values[key]?.toString() ?? '';

  @override
  bool getBool(String key) => switch (_values[key]) {
    final bool value => value,
    final String value => value.toLowerCase() == 'true',
    _ => false,
  };

  @override
  int getInt(String key) => switch (_values[key]) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value) ?? 0,
    _ => 0,
  };

  @override
  double getDouble(String key) => switch (_values[key]) {
    final num value => value.toDouble(),
    final String value => double.tryParse(value) ?? 0,
    _ => 0,
  };

  @override
  Stream<void> get onUpdated => _updated.stream;

  @override
  Future<bool> refresh() async => false;

  @override
  Future<void> dispose() => _updated.close();
}
