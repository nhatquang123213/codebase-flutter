import 'dart:io';

import 'package:dio/dio.dart';

import '../utils/app_logger.dart';
import 'failure.dart';
import 'result.dart';

/// Runs [action] and converts any thrown error into a [Failed] result,
/// so repositories never leak exceptions to upper layers.
Future<Result<T>> guard<T>(Future<T> Function() action) async {
  try {
    return Success(await action());
  } on DioException catch (e, st) {
    AppLogger.error('API ${e.requestOptions.path} failed', e, st);
    return Failed(mapDioException(e));
  } catch (e, st) {
    AppLogger.error('Unexpected error', e, st);
    return Failed(UnknownFailure(e.toString()));
  }
}

Failure mapDioException(DioException e) => switch (e.type) {
  DioExceptionType.connectionTimeout ||
  DioExceptionType.sendTimeout ||
  DioExceptionType.receiveTimeout => TimeoutFailure(e.message),
  DioExceptionType.connectionError => NetworkFailure(e.message),
  DioExceptionType.badResponse => _fromResponse(e.response),
  DioExceptionType.unknown when e.error is SocketException => NetworkFailure(
    e.message,
  ),
  _ => UnknownFailure(e.message),
};

Failure _fromResponse(Response<dynamic>? response) {
  final statusCode = response?.statusCode;
  final data = response?.data;
  final message = data is Map && data['message'] is String
      ? data['message'] as String
      : response?.statusMessage;
  if (statusCode == 401) return UnauthorizedFailure(message);
  return ServerFailure(statusCode: statusCode, message: message);
}
