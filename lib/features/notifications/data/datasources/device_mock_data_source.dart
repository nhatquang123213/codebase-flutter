import '../../../../core/utils/app_logger.dart';
import 'device_remote_data_source.dart';

/// Used when `USE_MOCK_API=true`: just logs the token so it can be copied
/// into the Firebase console "Send test message" dialog.
class DeviceMockDataSource implements DeviceRemoteDataSource {
  const DeviceMockDataSource();

  @override
  Future<void> registerToken(String token) async {
    AppLogger.info('[mock] FCM token registered: $token');
  }
}
