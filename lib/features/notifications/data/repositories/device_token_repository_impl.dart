import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/device_token_repository.dart';
import '../datasources/device_remote_data_source.dart';

class DeviceTokenRepositoryImpl implements DeviceTokenRepository {
  const DeviceTokenRepositoryImpl(this._remote);

  final DeviceRemoteDataSource _remote;

  @override
  Future<Result<void>> register(String token) =>
      guard(() => _remote.registerToken(token));
}
