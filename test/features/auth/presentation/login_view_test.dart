import 'package:bloc_test/bloc_test.dart';
import 'package:codebase_flutter/features/auth/domain/entities/user.dart';
import 'package:codebase_flutter/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:codebase_flutter/features/auth/presentation/cubit/login_cubit.dart';
import 'package:codebase_flutter/features/auth/presentation/pages/login_page.dart';
import 'package:codebase_flutter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoginCubit extends MockCubit<LoginState> implements LoginCubit {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  late _MockLoginCubit loginCubit;
  late _MockAuthBloc authBloc;

  setUp(() {
    loginCubit = _MockLoginCubit();
    authBloc = _MockAuthBloc();
    when(() => loginCubit.state).thenReturn(const LoginState());
    when(() => authBloc.state).thenReturn(const AuthState.unauthenticated());
  });

  Future<void> pumpLogin(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<LoginCubit>.value(value: loginCubit),
        ],
        child: const LoginView(),
      ),
    ),
  );

  testWidgets('shows validation errors and does not submit empty form', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('This field is required'), findsNWidgets(2));
    verifyNever(
      () => loginCubit.submit(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('submits valid credentials', (tester) async {
    when(
      () => loginCubit.submit(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    verify(
      () => loginCubit.submit(email: 'a@b.com', password: '123456'),
    ).called(1);
  });

  testWidgets('notifies AuthBloc on login success', (tester) async {
    const user = User(id: '1', email: 'a@b.com', name: 'A');
    whenListen(
      loginCubit,
      Stream.value(const LoginState(status: LoginStatus.success, user: user)),
      initialState: const LoginState(),
    );
    await pumpLogin(tester);
    await tester.pump();

    verify(() => authBloc.add(const AuthLoggedIn(user))).called(1);
  });
}
