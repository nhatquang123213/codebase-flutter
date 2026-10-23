import 'package:codebase_flutter/core/config/feature_flags.dart';
import 'package:codebase_flutter/core/config/remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('InMemoryRemoteConfigService serves defaults and typed overrides', () {
    final config = InMemoryRemoteConfigService({'retries': '3', 'ratio': 0.5});

    expect(config.getString(RemoteConfigKeys.minSupportedVersion), '0.0.0');
    expect(config.getBool(RemoteConfigKeys.exampleFeatureEnabled), isFalse);
    expect(config.getInt('retries'), 3);
    expect(config.getDouble('ratio'), 0.5);
    expect(config.getString('missing'), '');
  });

  test(
    'update notifies listeners and FeatureFlags reads live values',
    () async {
      final config = InMemoryRemoteConfigService();
      final flags = FeatureFlags(config);
      final updates = <void>[];
      config.onUpdated.listen(updates.add);

      config.update({RemoteConfigKeys.exampleFeatureEnabled: true});
      await Future<void>.delayed(Duration.zero);

      expect(flags.exampleFeature, isTrue);
      expect(updates, hasLength(1));
    },
  );
}
