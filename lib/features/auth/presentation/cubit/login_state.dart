part of 'login_cubit.dart';

enum LoginStatus { initial, submitting, success, failure }

final class LoginState extends Equatable {
  const LoginState({
    this.status = LoginStatus.initial,
    this.user,
    this.failure,
  });

  final LoginStatus status;
  final User? user;
  final Failure? failure;

  @override
  List<Object?> get props => [status, user, failure];
}
