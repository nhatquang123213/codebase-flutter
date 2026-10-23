import 'package:bloc_test/bloc_test.dart';
import 'package:codebase_flutter/core/config/remote_config.dart';
import 'package:codebase_flutter/features/app_update/domain/app_version.dart';
import 'package:codebase_flutter/features/app_update/domain/update_policy.dart';
import 'package:codebase_flutter/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const current = AppVersion(1, 2, 0);
  late InMemoryRemoteConfigService config;

  setUp(() => config = InMemoryRemoteConfigService());

  AppUpdateCubit build({TargetPlatform platform = TargetPlatform.android}) =>
      AppUpdateCubit(
        config: config,
        currentVersion: current,
        platform: platform,
      );

  blocTest<AppUpdateCubit, AppUpdateState>(
    'defaults mean no update',
    build: build,
    act: (cubit) => cubit.start(),
    expect: () => const [AppUpdateState(latestVersion: AppVersion(0, 0, 0))],
  );

  blocTest<AppUpdateCubit, AppUpdateState>(
    'blocks when below min_supported_version and picks the iOS store url',
    setUp: () => config.update({
      RemoteConfigKeys.minSupportedVersion: '1.3.0',
      RemoteConfigKeys.latestVersion: '1.4.0',
      RemoteConfigKeys.storeUrlIos: 'https://apps.apple.com/app/id1',
      RemoteConfigKeys.storeUrlAndroid: 'https://play.google.com/x',
    }),
    build: () => build(platform: TargetPlatform.iOS),
    act: (cubit) => cubit.start(),
    expect: () => [
      AppUpdateState(
        requirement: UpdateRequirement.required,
        latestVersion: const AppVersion(1, 4, 0),
        storeUrl: Uri.parse('https://apps.apple.com/app/id1'),
      ),
    ],
    verify: (cubit) => expect(cubit.state.isBlocking, isTrue),
  );

  blocTest<AppUpdateCubit, AppUpdateState>(
    'optional update can be dismissed, and a config push re-evaluates',
    setUp: () => config.update({RemoteConfigKeys.latestVersion: '1.3.0'}),
    build: build,
    act: (cubit) async {
      cubit.start();
      cubit.dismiss();
      config.update({RemoteConfigKeys.minSupportedVersion: '1.3.0'});
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => const [
      AppUpdateState(
        requirement: UpdateRequirement.optional,
        latestVersion: AppVersion(1, 3, 0),
      ),
      AppUpdateState(
        requirement: UpdateRequirement.optional,
        latestVersion: AppVersion(1, 3, 0),
        dismissed: true,
      ),
      // Verdict got stricter → dismissal is dropped.
      AppUpdateState(
        requirement: UpdateRequirement.required,
        latestVersion: AppVersion(1, 3, 0),
      ),
    ],
  );

  blocTest<AppUpdateCubit, AppUpdateState>(
    'required update cannot be dismissed',
    setUp: () => config.update({RemoteConfigKeys.minSupportedVersion: '9.0.0'}),
    build: build,
    act: (cubit) => cubit
      ..start()
      ..dismiss(),
    expect: () => const [
      AppUpdateState(
        requirement: UpdateRequirement.required,
        latestVersion: AppVersion(0, 0, 0),
      ),
    ],
  );

  blocTest<AppUpdateCubit, AppUpdateState>(
    'does nothing when the running version is unknown',
    setUp: () => config.update({RemoteConfigKeys.minSupportedVersion: '9.0.0'}),
    build: () => AppUpdateCubit(
      config: config,
      currentVersion: null,
      platform: TargetPlatform.android,
    ),
    act: (cubit) => cubit.start(),
    expect: () => const <AppUpdateState>[],
  );
}
