part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

final class AuthState extends Equatable {
  const AuthState._({
    required this.status,
    this.user,
    this.sessionExpired = false,
  });

  const AuthState.unknown() : this._(status: AuthStatus.unknown);

  const AuthState.authenticated(User user)
    : this._(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated({bool sessionExpired = false})
    : this._(
        status: AuthStatus.unauthenticated,
        sessionExpired: sessionExpired,
      );

  final AuthStatus status;
  final User? user;

  /// True when logged out because the refresh token expired (show a message).
  final bool sessionExpired;

  @override
  List<Object?> get props => [status, user, sessionExpired];
}
