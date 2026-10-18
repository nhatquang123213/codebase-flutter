import 'package:dio/dio.dart';

import '../../events/app_events.dart';
import '../../events/event_bus.dart';
import '../../storage/token_storage.dart';
import '../../utils/app_logger.dart';
import '../api_endpoints.dart';
import '../request_extra.dart';

/// Attaches the access token and transparently refreshes it on 401.
///
/// Extends [QueuedInterceptor] so concurrent 401s are handled one at a time:
/// the first one refreshes, the rest see the new token and just retry.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required Dio refreshClient,
    required AppEventBus eventBus,
  }) : _tokenStorage = tokenStorage,
       _refreshClient = refreshClient,
       _eventBus = eventBus;

  static const String _header = 'Authorization';

  final TokenStorage _tokenStorage;

  /// Must NOT have this interceptor attached, otherwise retries would deadlock the queue.
  final Dio _refreshClient;
  final AppEventBus _eventBus;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.requiresAuth) {
      final token = await _tokenStorage.readAccessToken();
      if (token != null) options.headers[_header] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        !request.requiresAuth ||
        request.isRetry) {
      handler.next(err);
      return;
    }

    final failedToken = _bearerToken(request);
    final currentToken = await _tokenStorage.readAccessToken();
    final newToken = currentToken != null && currentToken != failedToken
        ? currentToken // Another request already refreshed it.
        : await _refreshAccessToken();

    if (newToken == null) {
      await _tokenStorage.clear();
      _eventBus.fire(const SessionExpired());
      handler.next(err);
      return;
    }

    try {
      handler.resolve(await _retry(request, newToken));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  String? _bearerToken(RequestOptions options) {
    final header = options.headers[_header];
    return header is String && header.startsWith('Bearer ')
        ? header.substring(7)
        : null;
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) return null;
    try {
      final response = await _refreshClient.post<Map<String, dynamic>>(
        ApiEndpoints.refreshToken,
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      final accessToken = data?['access_token'];
      if (accessToken is! String) return null;
      final newRefreshToken = data?['refresh_token'];
      await _tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken is String
            ? newRefreshToken
            : refreshToken,
      );
      return accessToken;
    } on DioException catch (e, st) {
      AppLogger.error('Refresh token failed', e, st);
      return null;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions request, String token) =>
      _refreshClient.fetch<dynamic>(
        request.copyWith(
          headers: {...request.headers, _header: 'Bearer $token'},
          extra: {...request.extra, RequestExtra.isRetry: true},
        ),
      );
}
