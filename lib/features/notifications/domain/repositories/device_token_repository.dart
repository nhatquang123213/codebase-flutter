import '../../../../core/error/result.dart';

/// Tells the backend which FCM token belongs to the signed-in user.
abstract interface class DeviceTokenRepository {
  Future<Result<void>> register(String token);
}
