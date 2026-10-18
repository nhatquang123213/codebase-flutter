import 'package:codebase_flutter/core/events/app_events.dart';
import 'package:codebase_flutter/core/events/event_bus.dart';
import 'package:codebase_flutter/core/network/api_endpoints.dart';
import 'package:codebase_flutter/core/network/interceptors/auth_interceptor.dart';
import 'package:codebase_flutter/core/network/request_extra.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_token_storage.dart';

const _baseUrl = 'https://api.test';

void main() {
  late FakeTokenStorage tokenStorage;
  late AppEventBus eventBus;
  late Dio dio;
  late Dio refreshClient;
  late FakeHttpAdapter apiAdapter;
  late FakeHttpAdapter refreshAdapter;

  /// API accepts only `valid-token`; refresh endpoint returns [refreshStatus].
  void setUpClients({int refreshStatus = 200}) {
    ResponseBody api(RequestOptions o) =>
        o.headers['Authorization'] == 'Bearer valid-token'
        ? jsonResponse({'ok': true})
        : jsonResponse({'message': 'expired'}, 401);

    apiAdapter = FakeHttpAdapter(api);
    refreshAdapter = FakeHttpAdapter(
      (o) => o.path == ApiEndpoints.refreshToken
          ? jsonResponse({
              'access_token': 'valid-token',
              'refresh_token': 'new-refresh',
            }, refreshStatus)
          : api(o),
    );
    refreshClient = Dio(BaseOptions(baseUrl: _baseUrl))
      ..httpClientAdapter = refreshAdapter;
    dio = Dio(BaseOptions(baseUrl: _baseUrl))
      ..httpClientAdapter = apiAdapter
      ..interceptors.add(
        AuthInterceptor(
          tokenStorage: tokenStorage,
          refreshClient: refreshClient,
          eventBus: eventBus,
        ),
      );
  }

  int refreshCalls() => refreshAdapter.requests
      .where((r) => r.path == ApiEndpoints.refreshToken)
      .length;

  setUp(() {
    tokenStorage = FakeTokenStorage(
      accessToken: 'expired-token',
      refreshToken: 'old-refresh',
    );
    eventBus = AppEventBus();
  });

  tearDown(() => eventBus.dispose());

  test('attaches bearer token', () async {
    tokenStorage.accessToken = 'valid-token';
    setUpClients();

    await dio.get<dynamic>('/profile');

    expect(
      apiAdapter.requests.single.headers['Authorization'],
      'Bearer valid-token',
    );
  });

  test('does not attach token to public endpoints', () async {
    setUpClients();

    await expectLater(
      dio.post<dynamic>(ApiEndpoints.login, options: publicApi),
      throwsA(isA<DioException>()),
    );

    expect(apiAdapter.requests.single.headers['Authorization'], isNull);
    expect(refreshCalls(), 0);
  });

  test('refreshes token on 401 and retries the request', () async {
    setUpClients();

    final response = await dio.get<dynamic>('/profile');

    expect(response.statusCode, 200);
    expect(refreshCalls(), 1);
    expect(tokenStorage.accessToken, 'valid-token');
    expect(tokenStorage.refreshToken, 'new-refresh');
  });

  test('concurrent 401s trigger a single refresh', () async {
    setUpClients();

    final responses = await Future.wait([
      dio.get<dynamic>('/a'),
      dio.get<dynamic>('/b'),
      dio.get<dynamic>('/c'),
    ]);

    expect(responses.map((r) => r.statusCode), everyElement(200));
    expect(refreshCalls(), 1);
  });

  test('clears session and notifies when refresh fails', () async {
    setUpClients(refreshStatus: 401);
    var expiredEvents = 0;
    final sub = eventBus.on<SessionExpired>().listen((_) => expiredEvents++);

    await expectLater(
      dio.get<dynamic>('/profile'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(tokenStorage.accessToken, isNull);
    expect(tokenStorage.refreshToken, isNull);
    expect(expiredEvents, 1);
    await sub.cancel();
  });
}
