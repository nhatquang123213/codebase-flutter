import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';

/// Throws [DioException] on failure; the repository converts it to a `Failure`.
abstract interface class DeviceRemoteDataSource {
  Future<void> registerToken(String token);
}

class DeviceRemoteDataSourceImpl implements DeviceRemoteDataSource {
  const DeviceRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> registerToken(String token) async {
    await _dio.post<void>(
      ApiEndpoints.deviceTokens,
      data: {'token': token, 'platform': Platform.operatingSystem},
    );
  }
}
