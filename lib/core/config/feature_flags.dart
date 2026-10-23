import 'remote_config.dart';

/// Typed access to feature flags so call sites never spell raw keys.
///
/// Flags are read live, so a widget that should react to a flip listens to
/// `RemoteConfigService.onUpdated` (or just rebuilds on next visit).
class FeatureFlags {
  const FeatureFlags(this._config);

  final RemoteConfigService _config;

  /// Example — replace with real flags, one getter per key.
  bool get exampleFeature =>
      _config.getBool(RemoteConfigKeys.exampleFeatureEnabled);
}
