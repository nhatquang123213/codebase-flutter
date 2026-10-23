import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/extensions/context_x.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import 'app_routes.dart';

/// Navigation is driven by [AuthBloc]: pages never push login/home themselves,
/// they change auth state and [_redirect] does the rest.
class AppRouter {
  AppRouter(this._authBloc, {List<NavigatorObserver> observers = const []})
    : _observers = observers;

  final AuthBloc _authBloc;
  final List<NavigatorObserver> _observers;
  late final _refresh = _StreamListenable(_authBloc.stream);

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: !Env.isProd,
    refreshListenable: _refresh,
    observers: _observers,
    redirect: _redirect,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: AppRoutes.home, builder: (_, _) => const HomePage()),
    ],
    errorBuilder: (context, _) =>
        Scaffold(body: Center(child: Text(context.l10n.pageNotFound))),
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;
    return switch (_authBloc.state.status) {
      AuthStatus.unknown =>
        location == AppRoutes.splash ? null : AppRoutes.splash,
      AuthStatus.unauthenticated =>
        location == AppRoutes.login ? null : AppRoutes.login,
      AuthStatus.authenticated =>
        location == AppRoutes.splash || location == AppRoutes.login
            ? AppRoutes.home
            : null,
    };
  }

  void dispose() {
    _refresh.dispose();
    router.dispose();
  }
}

class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
