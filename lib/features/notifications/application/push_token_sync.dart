import 'dart:async';

import '../../../core/error/result.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../domain/usecases/register_device_token_usecase.dart';

/// Keeps the backend's copy of this device's FCM token in step with the session:
///
/// * login (or app start with a saved session) → ask permission, send token
/// * FCM rotates the token while logged in     → send the new one
/// * logout / session expired                  → delete the token locally, so
///   the device stops receiving the previous user's pushes and the next login
///   gets a fresh token. No API call is made here on purpose: tokens are
///   already cleared, and an unauthenticated request would trip the
///   session-expired flow.
class PushTokenSync {
  PushTokenSync({
    required PushNotificationService push,
    required RegisterDeviceTokenUseCase registerToken,
  }) : _push = push,
       _registerToken = registerToken;

  final PushNotificationService _push;
  final RegisterDeviceTokenUseCase _registerToken;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  AuthStatus _status = AuthStatus.unknown;

  /// [states] must start with the current state (e.g. `bloc.stream` after
  /// passing `bloc.state` as [initial]).
  void start({required AuthState initial, required Stream<AuthState> states}) {
    _subscriptions
      ..add(states.listen(_onAuthChanged))
      ..add(_push.onTokenRefresh.listen(_onTokenRefresh));
    _onAuthChanged(initial);
  }

  Future<void> _onAuthChanged(AuthState state) async {
    final previous = _status;
    _status = state.status;
    if (state.status == previous) return;

    switch (state.status) {
      case AuthStatus.authenticated:
        await _syncToken();
      case AuthStatus.unauthenticated when previous == AuthStatus.authenticated:
        await _push.deleteToken();
      case AuthStatus.unauthenticated || AuthStatus.unknown:
        break;
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    if (_status == AuthStatus.authenticated) await _register(token);
  }

  Future<void> _syncToken() async {
    if (!await _push.requestPermission()) return;
    final token = await _push.getToken();
    if (token != null) await _register(token);
  }

  Future<void> _register(String token) async {
    // Failures are logged, not surfaced: a push token is not worth an error
    // dialog, and the next launch / token refresh retries anyway.
    final result = await _registerToken(token);
    if (result case Failed(:final failure)) {
      AppLogger.warning('Could not register FCM token: $failure');
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}
