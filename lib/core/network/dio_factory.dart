import 'package:dio/dio.dart';

import '../config/env.dart';
import '../utils/app_logger.dart';

abstract final class DioInstance {
  /// Bare client without auth interceptor — used for refresh token & retries.
  static const String plain = 'plainDio';
}

Dio createDio({
  required String baseUrl,
  Iterable<Interceptor> interceptors = const [],
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Env.connectTimeout,
      receiveTimeout: Env.receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
  dio.interceptors.addAll(interceptors);
  if (!Env.isProd) {
    dio.interceptors.add(
      LogInterceptor(
        // Headers & request body may hold tokens / passwords.
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: true,
        logPrint: (o) => AppLogger.debug(o.toString()),
      ),
    );
  }
  return dio;
}
