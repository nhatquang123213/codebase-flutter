import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/env.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/extensions/context_x.dart';
import '../../../../core/extensions/failure_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../data/datasources/auth_mock_data_source.dart';
import '../bloc/auth_bloc.dart';
import '../cubit/login_cubit.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<LoginCubit>(),
      child: const LoginView(),
    );
  }
}

/// Separated from [LoginPage] so tests can inject a mock cubit.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (context.read<AuthBloc>().state.sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.showSnackBar(context.l10n.errorUnauthorized, isError: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    context.read<LoginCubit>().submit(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  void _onStateChanged(BuildContext context, LoginState state) {
    switch (state.status) {
      case LoginStatus.success:
        context.read<AuthBloc>().add(AuthLoggedIn(state.user!));
      case LoginStatus.failure:
        final failure = state.failure!;
        context.showSnackBar(
          failure is UnauthorizedFailure
              ? context.l10n.invalidCredentials
              : failure.localizedMessage(context.l10n),
          isError: true,
        );
      case LoginStatus.initial || LoginStatus.submitting:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.login)),
      body: BlocListener<LoginCubit, LoginState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: _onStateChanged,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: l10n.email),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.fieldRequired;
                      }
                      return Validators.isValidEmail(value)
                          ? null
                          : l10n.emailInvalid;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.fieldRequired;
                      }
                      return Validators.isValidPassword(value)
                          ? null
                          : l10n.passwordTooShort(Validators.minPasswordLength);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  BlocSelector<LoginCubit, LoginState, bool>(
                    selector: (state) => state.status == LoginStatus.submitting,
                    builder: (context, isSubmitting) => AppButton(
                      label: l10n.login,
                      isLoading: isSubmitting,
                      onPressed: _submit,
                    ),
                  ),
                  if (Env.useMockApi) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.demoAccountHint(
                        AuthMockDataSource.demoEmail,
                        AuthMockDataSource.demoPassword,
                      ),
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
