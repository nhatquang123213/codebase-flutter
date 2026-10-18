import 'dart:async';

import 'package:codebase_flutter/core/notifications/notification_payload.dart';
import 'package:codebase_flutter/core/notifications/push_notification_service.dart';

/// In-memory FCM stand-in: tests push events into the controllers and
/// assert on the recorded calls.
class FakePushNotificationService implements PushNotificationService {
  FakePushNotificationService({this.token = 'token-1', this.permission = true});

  String? token;
  bool permission;
  int permissionRequests = 0;
  int deleteTokenCalls = 0;
  NotificationPayload? initialMessage;

  final tokenRefresh = StreamController<String>.broadcast();
  final foreground = StreamController<NotificationPayload>.broadcast();
  final opened = StreamController<NotificationPayload>.broadcast();

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;

  @override
  Future<void> deleteToken() async {
    deleteTokenCalls++;
    token = null;
  }

  @override
  Stream<NotificationPayload> get onForegroundMessage => foreground.stream;

  @override
  Stream<NotificationPayload> get onMessageOpenedApp => opened.stream;

  @override
  Future<NotificationPayload?> getInitialMessage() async => initialMessage;

  Future<void> dispose() async {
    await tokenRefresh.close();
    await foreground.close();
    await opened.close();
  }
}
