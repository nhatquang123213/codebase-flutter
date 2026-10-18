import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/request_extra.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// Throws [DioException] on failure; the repository converts it to a `Failure`.
abstract interface class AuthRemoteDataSource {
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  });

  Future<UserModel> getCurrentUser();

  Future<void> logout();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
      options: publicApi,
    );
    return AuthResponseModel.fromJson(response.requireData);
  }

  @override
  Future<UserModel> getCurrentUser() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.me);
    return UserModel.fromJson(response.requireData);
  }

  @override
  Future<void> logout() => _dio.post<void>(ApiEndpoints.logout);
}
