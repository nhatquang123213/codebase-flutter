import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login_usecase.dart';

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._login) : super(const LoginState());

  final LoginUseCase _login;

  Future<void> submit({required String email, required String password}) async {
    if (state.status == LoginStatus.submitting) return;
    emit(const LoginState(status: LoginStatus.submitting));
    final result = await _login(
      LoginParams(email: email.trim(), password: password),
    );
    emit(switch (result) {
      Success(:final data) => LoginState(
        status: LoginStatus.success,
        user: data,
      ),
      Failed(:final failure) => LoginState(
        status: LoginStatus.failure,
        failure: failure,
      ),
    });
  }
}
