import 'package:codebase_flutter/core/error/failure.dart';
import 'package:codebase_flutter/core/error/result.dart';
import 'package:codebase_flutter/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:codebase_flutter/features/auth/data/models/auth_response_model.dart';
import 'package:codebase_flutter/features/auth/data/models/user_model.dart';
import 'package:codebase_flutter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:codebase_flutter/features/auth/domain/entities/user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_token_storage.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

void main() {
  const userModel = UserModel(id: '1', email: 'a@b.com', name: 'A');
  const user = User(id: '1', email: 'a@b.com', name: 'A');

  late _MockRemote remote;
  late FakeTokenStorage tokenStorage;
  late AuthRepositoryImpl repository;

  setUp(() {
    remote = _MockRemote();
    tokenStorage = FakeTokenStorage();
    repository = AuthRepositoryImpl(remote: remote, tokenStorage: tokenStorage);
  });

  group('login', () {
    test('saves tokens and returns user', () async {
      when(() => remote.login(email: 'a@b.com', password: '123456')).thenAnswer(
        (_) async => const AuthResponseModel(
          accessToken: 'access',
          refreshToken: 'refresh',
          user: userModel,
        ),
      );

      final result = await repository.login(
        email: 'a@b.com',
        password: '123456',
      );

      expect(result, const Success(user));
      expect(tokenStorage.accessToken, 'access');
      expect(tokenStorage.refreshToken, 'refresh');
    });

    test('maps 401 to UnauthorizedFailure', () async {
      final request = RequestOptions(path: '/auth/login');
      when(
        () => remote.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        DioException.badResponse(
          statusCode: 401,
          requestOptions: request,
          response: Response(requestOptions: request, statusCode: 401),
        ),
      );

      final result = await repository.login(email: 'a@b.com', password: 'x');

      expect(result, isA<Failed<User>>());
      expect((result as Failed).failure, isA<UnauthorizedFailure>());
      expect(tokenStorage.accessToken, isNull);
    });

    test('maps connection error to NetworkFailure', () async {
      when(
        () => remote.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/auth/login'),
          reason: 'offline',
        ),
      );

      final result = await repository.login(email: 'a@b.com', password: 'x');

      expect((result as Failed).failure, isA<NetworkFailure>());
    });
  });

  test('getCurrentUser fails without calling API when no token', () async {
    final result = await repository.getCurrentUser();

    expect(result, const Failed<User>(UnauthorizedFailure()));
    verifyNever(() => remote.getCurrentUser());
  });

  test('logout clears tokens even if API fails', () async {
    tokenStorage
      ..accessToken = 'access'
      ..refreshToken = 'refresh';
    when(() => remote.logout()).thenThrow(
      DioException.connectionError(
        requestOptions: RequestOptions(path: '/auth/logout'),
        reason: 'offline',
      ),
    );

    await repository.logout();

    expect(tokenStorage.accessToken, isNull);
    expect(tokenStorage.refreshToken, isNull);
  });
}
