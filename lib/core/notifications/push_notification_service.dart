import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../utils/app_logger.dart';
import 'notification_payload.dart';

/// Thin wrapper over FCM so the rest of the app (and tests) never import
/// `firebase_messaging` directly.
///
/// This uses classic *registration tokens*, which is what Firebase Admin SDK
/// `send({token})` and virtually every backend expect. firebase_messaging 17
/// marks them deprecated in favour of Installation-ID "direct send"
/// (`register()` / `onRegistered`); switch when the backend supports it.
abstract interface class PushNotificationService {
  /// Asks the OS for permission. Returns true when alerts may be shown.
  Future<bool> requestPermission();

  Future<String?> getToken();

  /// Emits whenever FCM rotates the device token; re-register it with the backend.
  Stream<String> get onTokenRefresh;

  /// Invalidate the current token (call on logout so the device stops
  /// receiving pushes meant for the previous user).
  Future<void> deleteToken();

  /// Messages received while the app is in the foreground.
  Stream<NotificationPayload> get onForegroundMessage;

  /// User tapped a notification while the app was in the background.
  Stream<NotificationPayload> get onMessageOpenedApp;

  /// The notification that launched the app from a terminated state, if any.
  Future<NotificationPayload?> getInitialMessage();
}

class FirebasePushNotificationService implements PushNotificationService {
  FirebasePushNotificationService(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    // iOS: show banners while the app is in the foreground too.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    final status = settings.authorizationStatus;
    AppLogger.info('Push permission: ${status.name}');
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  @override
  // ignore: deprecated_member_use
  Future<String?> getToken() => _messaging.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  // ignore: deprecated_member_use
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<NotificationPayload> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(toPayload);

  @override
  Stream<NotificationPayload> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(toPayload);

  @override
  Future<NotificationPayload?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : toPayload(message);
  }

  static NotificationPayload toPayload(RemoteMessage message) =>
      NotificationPayload(
        id: message.messageId,
        title: message.notification?.title,
        body: message.notification?.body,
        data: message.data.map((key, value) => MapEntry(key, value.toString())),
      );
}

/// Used when Firebase is not configured (fresh clone, tests, CI).
class NoopPushNotificationService implements PushNotificationService {
  const NoopPushNotificationService();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Future<void> deleteToken() async {}

  @override
  Stream<NotificationPayload> get onForegroundMessage => const Stream.empty();

  @override
  Stream<NotificationPayload> get onMessageOpenedApp => const Stream.empty();

  @override
  Future<NotificationPayload?> getInitialMessage() async => null;
}
