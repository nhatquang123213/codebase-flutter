import '../../../../core/error/failure.dart';
import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required TokenStorage tokenStorage,
  }) : _remote = remote,
       _tokenStorage = tokenStorage;

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokenStorage;

  @override
  Future<Result<User>> login({
    required String email,
    required String password,
  }) => guard(() async {
    final response = await _remote.login(email: email, password: password);
    await _tokenStorage.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );
    return response.user.toEntity();
  });

  @override
  Future<Result<User>> getCurrentUser() async {
    if (await _tokenStorage.readAccessToken() == null) {
      return const Failed(UnauthorizedFailure());
    }
    return guard(() async => (await _remote.getCurrentUser()).toEntity());
  }

  @override
  Future<Result<void>> logout() async {
    final result = await guard(_remote.logout);
    await _tokenStorage.clear();
    return result;
  }
}
