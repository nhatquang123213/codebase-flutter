import '../realtime/realtime_message.dart';
import 'app_event.dart';

/// The refresh token was rejected; the user must log in again.
/// Fired by `AuthInterceptor`, handled by `AuthBloc`.
final class SessionExpired extends AppEvent {
  const SessionExpired();
}

/// Fired by `ConnectivityService` whenever the device goes on/offline.
final class ConnectivityChanged extends AppEvent {
  const ConnectivityChanged({required this.isOnline});

  final bool isOnline;

  @override
  String toString() => 'ConnectivityChanged(isOnline: $isOnline)';
}

/// A message arrived on the realtime (WebSocket) connection.
/// Features filter on [RealtimeMessage.type].
final class RealtimeMessageReceived extends AppEvent {
  const RealtimeMessageReceived(this.message);

  final RealtimeMessage message;

  @override
  String toString() => 'RealtimeMessageReceived(${message.type})';
}
