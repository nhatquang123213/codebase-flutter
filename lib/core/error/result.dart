import 'package:equatable/equatable.dart';

import 'failure.dart';

/// Return type of every repository / use case. Use `switch` to handle both cases:
///
/// ```dart
/// switch (result) {
///   case Success(:final data): ...
///   case Failed(:final failure): ...
/// }
/// ```
sealed class Result<T> extends Equatable {
  const Result();

  R fold<R>(
    R Function(Failure failure) onFailure,
    R Function(T data) onSuccess,
  ) => switch (this) {
    Success<T>(:final data) => onSuccess(data),
    Failed<T>(:final failure) => onFailure(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;

  @override
  List<Object?> get props => [data];
}

final class Failed<T> extends Result<T> {
  const Failed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
