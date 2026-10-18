import '../error/result.dart';

abstract interface class UseCase<T, Params> {
  Future<Result<T>> call(Params params);
}

final class NoParams {
  const NoParams();
}
