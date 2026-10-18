import 'package:dio/dio.dart';

abstract final class RequestExtra {
  static const String requiresAuth = 'requiresAuth';
  static const String isRetry = 'isRetry';
}

/// Pass as `options:` for endpoints that must not carry an access token
/// (login, register, refresh...).
final Options publicApi = Options(extra: {RequestExtra.requiresAuth: false});

extension RequestOptionsAuthX on RequestOptions {
  bool get requiresAuth => extra[RequestExtra.requiresAuth] != false;

  bool get isRetry => extra[RequestExtra.isRetry] == true;
}

extension ResponseDataX<T> on Response<T> {
  /// Response body, or throws [FormatException] (mapped to a Failure by `guard`).
  T get requireData {
    final body = data;
    if (body == null) {
      throw FormatException('Empty response body: ${requestOptions.path}');
    }
    return body;
  }
}
