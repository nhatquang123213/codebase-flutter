import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/device_token_repository.dart';

class RegisterDeviceTokenUseCase implements UseCase<void, String> {
  const RegisterDeviceTokenUseCase(this._repository);

  final DeviceTokenRepository _repository;

  @override
  Future<Result<void>> call(String token) => _repository.register(token);
}
