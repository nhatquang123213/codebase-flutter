import 'dart:async';

import 'package:codebase_flutter/core/error/failure.dart';
import 'package:codebase_flutter/core/error/result.dart';
import 'package:codebase_flutter/features/auth/domain/entities/user.dart';
import 'package:codebase_flutter/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:codebase_flutter/features/notifications/application/push_token_sync.dart';
import 'package:codebase_flutter/features/notifications/domain/usecases/register_device_token_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_push_notification_service.dart';

class _MockRegister extends Mock implements RegisterDeviceTokenUseCase {}

void main() {
  const user = User(id: '1', email: 'a@b.com', name: 'A');
  const authenticated = AuthState.authenticated(user);
  const unauthenticated = AuthState.unauthenticated();

  late FakePushNotificationService push;
  late _MockRegister register;
  late StreamController<AuthState> auth;
  late PushTokenSync sync;

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  setUp(() {
    push = FakePushNotificationService();
    register = _MockRegister();
    when(() => register(any())).thenAnswer((_) async => const Success(null));
    auth = StreamController<AuthState>.broadcast();
    sync = PushTokenSync(push: push, registerToken: register);
  });

  tearDown(() async {
    await sync.dispose();
    await auth.close();
    await push.dispose();
  });

  test('registers the token when already authenticated on start', () async {
    sync.start(initial: authenticated, states: auth.stream);
    await pump();

    expect(push.permissionRequests, 1);
    verify(() => register('token-1')).called(1);
  });

  test('registers on login and deletes the token on logout', () async {
    sync.start(initial: const AuthState.unknown(), states: auth.stream);
    await pump();
    verifyNever(() => register(any()));

    auth.add(authenticated);
    await pump();
    verify(() => register('token-1')).called(1);

    auth.add(unauthenticated);
    await pump();
    expect(push.deleteTokenCalls, 1);
  });

  test('does not register without permission', () async {
    push.permission = false;
    sync.start(initial: authenticated, states: auth.stream);
    await pump();

    verifyNever(() => register(any()));
  });

  test('re-registers on token refresh only while authenticated', () async {
    sync.start(initial: unauthenticated, states: auth.stream);
    push.tokenRefresh.add('token-2');
    await pump();
    verifyNever(() => register(any()));

    auth.add(authenticated);
    await pump();
    push.tokenRefresh.add('token-3');
    await pump();
    verify(() => register('token-3')).called(1);
  });

  test('ignores repeated authenticated states', () async {
    sync.start(initial: authenticated, states: auth.stream);
    auth.add(authenticated);
    await pump();

    verify(() => register('token-1')).called(1);
  });

  test('swallows registration failures', () async {
    when(
      () => register(any()),
    ).thenAnswer((_) async => const Failed(NetworkFailure()));
    sync.start(initial: authenticated, states: auth.stream);
    await pump();

    verify(() => register('token-1')).called(1);
  });
}
