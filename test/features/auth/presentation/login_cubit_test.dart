import 'package:bloc_test/bloc_test.dart';
import 'package:codebase_flutter/core/analytics/analytics.dart';
import 'package:codebase_flutter/core/error/failure.dart';
import 'package:codebase_flutter/core/error/result.dart';
import 'package:codebase_flutter/features/auth/domain/entities/user.dart';
import 'package:codebase_flutter/features/auth/domain/usecases/login_usecase.dart';
import 'package:codebase_flutter/features/auth/presentation/cubit/login_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoginUseCase extends Mock implements LoginUseCase {}

class _MockAnalytics extends Mock implements Analytics {}

void main() {
  const user = User(id: '1', email: 'a@b.com', name: 'A');
  const params = LoginParams(email: 'a@b.com', password: '123456');

  late _MockLoginUseCase login;
  late _MockAnalytics analytics;

  setUp(() {
    login = _MockLoginUseCase();
    analytics = _MockAnalytics();
    when(() => analytics.logLogin()).thenAnswer((_) async {});
  });

  blocTest<LoginCubit, LoginState>(
    'emits [submitting, success] and trims email',
    setUp: () =>
        when(() => login(params)).thenAnswer((_) async => const Success(user)),
    build: () => LoginCubit(login, analytics),
    act: (cubit) => cubit.submit(email: '  a@b.com ', password: '123456'),
    expect: () => const [
      LoginState(status: LoginStatus.submitting),
      LoginState(status: LoginStatus.success, user: user),
    ],
    verify: (_) => verify(() => analytics.logLogin()).called(1),
  );

  blocTest<LoginCubit, LoginState>(
    'emits [submitting, failure] on error',
    setUp: () => when(
      () => login(params),
    ).thenAnswer((_) async => const Failed(NetworkFailure())),
    build: () => LoginCubit(login, analytics),
    act: (cubit) => cubit.submit(email: 'a@b.com', password: '123456'),
    expect: () => const [
      LoginState(status: LoginStatus.submitting),
      LoginState(status: LoginStatus.failure, failure: NetworkFailure()),
    ],
    verify: (_) => verifyNever(() => analytics.logLogin()),
  );
}
