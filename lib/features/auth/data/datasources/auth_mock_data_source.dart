import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import 'auth_remote_data_source.dart';

/// Used when `USE_MOCK_API=true` so the app runs without a backend.
class AuthMockDataSource implements AuthRemoteDataSource {
  static const String demoEmail = 'demo@example.com';
  static const String demoPassword = '123456';

  static const UserModel _user = UserModel(
    id: '1',
    email: demoEmail,
    name: 'Demo User',
  );

  static const Duration _latency = Duration(milliseconds: 600);

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(_latency);
    if (email != demoEmail || password != demoPassword) {
      final request = RequestOptions(path: ApiEndpoints.login);
      throw DioException.badResponse(
        statusCode: 401,
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 401,
          data: {'message': 'Invalid credentials'},
        ),
      );
    }
    return const AuthResponseModel(
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
      user: _user,
    );
  }

  @override
  Future<UserModel> getCurrentUser() async {
    await Future<void>.delayed(_latency);
    return _user;
  }

  @override
  Future<void> logout() => Future<void>.delayed(_latency);
}
