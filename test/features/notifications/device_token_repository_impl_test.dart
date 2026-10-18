import 'package:codebase_flutter/core/error/failure.dart';
import 'package:codebase_flutter/core/error/result.dart';
import 'package:codebase_flutter/features/notifications/data/datasources/device_remote_data_source.dart';
import 'package:codebase_flutter/features/notifications/data/repositories/device_token_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late DeviceTokenRepositoryImpl repository;

  DeviceTokenRepositoryImpl build(FakeHandler handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    return DeviceTokenRepositoryImpl(DeviceRemoteDataSourceImpl(dio));
  }

  test('posts token and platform', () async {
    repository = build((_) => jsonResponse({}));

    final result = await repository.register('abc');

    expect(result, const Success<void>(null));
    final request = adapter.requests.single;
    expect(request.path, '/devices/tokens');
    expect(request.method, 'POST');
    final body = request.data as Map<String, dynamic>;
    expect(body['token'], 'abc');
    expect(body['platform'], isNotEmpty);
  });

  test('maps server errors to ServerFailure', () async {
    repository = build((_) => jsonResponse({'message': 'boom'}, 500));

    final result = await repository.register('abc');

    expect(result, isA<Failed<void>>());
    final failure = (result as Failed<void>).failure;
    expect(failure, isA<ServerFailure>());
    expect((failure as ServerFailure).statusCode, 500);
  });
}
