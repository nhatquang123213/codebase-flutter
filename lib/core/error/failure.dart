import 'package:equatable/equatable.dart';

/// Errors that cross from the data layer into domain/presentation.
///
/// UI maps the failure *type* to a localized message (see `FailureMessageX`);
/// [message] is the raw detail, mainly for logging.
sealed class Failure extends Equatable {
  const Failure([this.message]);

  final String? message;

  @override
  List<Object?> get props => [message];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message]);
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message]);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message]);
}

final class ServerFailure extends Failure {
  const ServerFailure({this.statusCode, String? message}) : super(message);

  final int? statusCode;

  @override
  List<Object?> get props => [statusCode, message];
}

final class CacheFailure extends Failure {
  const CacheFailure([super.message]);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message]);
}
