import '../../../../core/error/result.dart';
import '../entities/user.dart';

abstract interface class AuthRepository {
  Future<Result<User>> login({required String email, required String password});

  /// Fails with `UnauthorizedFailure` when there is no saved session.
  Future<Result<User>> getCurrentUser();

  /// Always clears the local session, even if the server call fails.
  Future<Result<void>> logout();
}
