import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/app_logger.dart';
import 'notification_payload.dart';

/// Android channel ids. Must match `default_notification_channel_id`
/// in `AndroidManifest.xml` so background FCM notifications land here too.
abstract final class NotificationChannels {
  static const AndroidNotificationChannel highImportance =
      AndroidNotificationChannel(
        'high_importance',
        'Notifications',
        description: 'General notifications',
        importance: Importance.high,
      );
}

/// Shows system notifications from Dart. Needed because FCM only renders a
/// notification itself when the app is in the background; in the foreground
/// we render it ourselves so the user still sees it.
class LocalNotificationService {
  LocalNotificationService(this._plugin);

  /// Monochrome icon in `android/app/src/main/res/drawable`. Replace the
  /// launcher icon with a proper notification icon before release.
  static const String _androidIcon = '@mipmap/ic_launcher';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<NotificationPayload> _taps =
      StreamController<NotificationPayload>.broadcast();

  /// User tapped a notification shown by [show].
  Stream<NotificationPayload> get onTap => _taps.stream;

  Future<void> init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_androidIcon),
        // Permission is requested through FCM; don't double-prompt here.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(NotificationChannels.highImportance);
  }

  /// The local notification that launched the app, if it was terminated.
  Future<NotificationPayload?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return NotificationPayload.decode(details?.notificationResponse?.payload);
  }

  Future<void> show(NotificationPayload payload) async {
    if (payload.title == null && payload.body == null) return;
    const channel = NotificationChannels.highImportance;
    try {
      await _plugin.show(
        id: payload.id.hashCode,
        title: payload.title,
        body: payload.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: channel.importance,
            priority: Priority.high,
            icon: _androidIcon,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: payload.encode(),
      );
    } catch (e, st) {
      // iOS throws when permission was denied; not worth crashing over.
      AppLogger.warning('Could not show local notification: $e');
      AppLogger.debug(st.toString());
    }
  }

  void _onResponse(NotificationResponse response) {
    final payload = NotificationPayload.decode(response.payload);
    if (payload != null) _taps.add(payload);
  }

  Future<void> dispose() => _taps.close();
}
