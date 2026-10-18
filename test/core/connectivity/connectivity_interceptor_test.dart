import 'package:codebase_flutter/core/connectivity/connectivity_interceptor.dart';
import 'package:codebase_flutter/core/error/failure.dart';
import 'package:codebase_flutter/core/error/guard.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_connectivity_service.dart';
import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeConnectivityService connectivity;
  late FakeHttpAdapter adapter;
  late Dio dio;

  setUp(() {
    connectivity = FakeConnectivityService();
    adapter = FakeHttpAdapter((_) => jsonResponse({'ok': true}));
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(ConnectivityInterceptor(connectivity));
  });

  tearDown(() => connectivity.dispose());

  test('passes requests through while online', () async {
    final response = await dio.get<dynamic>('/a');
    expect(response.statusCode, 200);
    expect(adapter.requests, hasLength(1));
  });

  test('rejects without hitting the network while offline', () async {
    connectivity.isOnline = false;

    final result = await guard(() => dio.get<dynamic>('/a'));

    expect(adapter.requests, isEmpty);
    expect(result.fold((f) => f, (_) => null), isA<NetworkFailure>());
  });
}
