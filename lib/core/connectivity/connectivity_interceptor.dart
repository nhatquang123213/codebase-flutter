import 'package:dio/dio.dart';

import 'connectivity_service.dart';

/// Fails requests immediately while offline instead of waiting for the
/// 30 s connect timeout. `guard` maps the error to `NetworkFailure`.
class ConnectivityInterceptor extends Interceptor {
  const ConnectivityInterceptor(this._connectivity);

  final ConnectivityService _connectivity;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_connectivity.isOnline) {
      handler.next(options);
      return;
    }
    handler.reject(
      DioException.connectionError(
        requestOptions: options,
        reason: 'Device is offline',
      ),
    );
  }
}
