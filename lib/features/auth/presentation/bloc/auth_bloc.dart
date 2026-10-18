import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/result.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/events/event_bus.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// App-wide session state. The router redirects based on [AuthState.status].
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required GetCurrentUserUseCase getCurrentUser,
    required LogoutUseCase logout,
    required AppEventBus eventBus,
  }) : _getCurrentUser = getCurrentUser,
       _logout = logout,
       super(const AuthState.unknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoggedIn>(_onLoggedIn);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<_AuthSessionExpired>(_onSessionExpired);
    _sessionSubscription = eventBus.on<SessionExpired>().listen(
      (_) => add(const _AuthSessionExpired()),
    );
  }

  final GetCurrentUserUseCase _getCurrentUser;
  final LogoutUseCase _logout;
  late final StreamSubscription<SessionExpired> _sessionSubscription;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final result = await _getCurrentUser();
    emit(switch (result) {
      Success(:final data) => AuthState.authenticated(data),
      Failed() => const AuthState.unauthenticated(),
    });
  }

  void _onLoggedIn(AuthLoggedIn event, Emitter<AuthState> emit) =>
      emit(AuthState.authenticated(event.user));

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _logout();
    emit(const AuthState.unauthenticated());
  }

  void _onSessionExpired(_AuthSessionExpired event, Emitter<AuthState> emit) =>
      emit(const AuthState.unauthenticated(sessionExpired: true));

  @override
  Future<void> close() async {
    await _sessionSubscription.cancel();
    return super.close();
  }
}
