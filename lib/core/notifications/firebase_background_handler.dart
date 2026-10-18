import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase/firebase_config.dart';
import '../utils/app_logger.dart';

/// Runs in its own isolate when a message arrives while the app is in the
/// background or terminated. Keep it fast and side-effect free: no DI,
/// no navigation, no network. FCM already renders `notification` messages;
/// this is the place to handle *data-only* messages (e.g. update a badge).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseConfig.ensureInitialized();
  AppLogger.debug('Background message ${message.messageId}: ${message.data}');
}
