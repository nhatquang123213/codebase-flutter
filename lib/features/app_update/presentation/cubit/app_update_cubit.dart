import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/remote_config.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/app_version.dart';
import '../../domain/update_policy.dart';

part 'app_update_state.dart';

/// Compares the running build with `min_supported_version` /
/// `latest_version` from remote config, and re-evaluates whenever the config
/// updates — so a bad release can be blocked without waiting for a restart.
class AppUpdateCubit extends Cubit<AppUpdateState> {
  AppUpdateCubit({
    required RemoteConfigService config,
    required AppVersion? currentVersion,
    TargetPlatform? platform,
  }) : _config = config,
       _current = currentVersion,
       _platform = platform ?? defaultTargetPlatform,
       super(const AppUpdateState());

  final RemoteConfigService _config;
  final AppVersion? _current;
  final TargetPlatform _platform;
  StreamSubscription<void>? _subscription;

  void start() {
    if (_current == null) {
      AppLogger.warning('App version unknown — update checks disabled');
      return;
    }
    _evaluate();
    _subscription ??= _config.onUpdated.listen((_) => _evaluate());
  }

  /// Hides the optional prompt for the rest of the session. A required
  /// update cannot be dismissed.
  void dismiss() {
    if (state.requirement == UpdateRequirement.optional) {
      emit(state.copyWith(dismissed: true));
    }
  }

  void _evaluate() {
    final latest = AppVersion.tryParse(
      _config.getString(RemoteConfigKeys.latestVersion),
    );
    final requirement = UpdatePolicy.evaluate(
      current: _current,
      minSupported: AppVersion.tryParse(
        _config.getString(RemoteConfigKeys.minSupportedVersion),
      ),
      latest: latest,
    );
    final storeUrl = _config.getString(
      _platform == TargetPlatform.iOS
          ? RemoteConfigKeys.storeUrlIos
          : RemoteConfigKeys.storeUrlAndroid,
    );
    emit(
      AppUpdateState(
        requirement: requirement,
        latestVersion: latest,
        storeUrl: storeUrl.isEmpty ? null : Uri.tryParse(storeUrl),
        // Keep the dismissal unless the verdict got stricter.
        dismissed: state.dismissed && requirement == state.requirement,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
