import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/analytics/analytics.dart';
import '../core/analytics/analytics_route_observer.dart';
import '../core/connectivity/connectivity_cubit.dart';
import '../core/connectivity/offline_banner.dart';
import '../core/di/injection.dart';
import '../core/notifications/notification_handler.dart';
import '../core/notifications/notification_payload.dart';
import '../core/realtime/realtime_session.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/app_logger.dart';
import '../features/app_update/presentation/cubit/app_update_cubit.dart';
import '../features/app_update/presentation/widgets/update_gate.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/notifications/application/push_token_sync.dart';
import '../features/settings/presentation/cubit/settings_cubit.dart';
import '../l10n/app_localizations.dart';
import 'router/app_router.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthBloc _authBloc = getIt<AuthBloc>()..add(const AuthStarted());
  late final Analytics _analytics = getIt<Analytics>();
  late final AppRouter _appRouter = AppRouter(
    _authBloc,
    observers: [AnalyticsRouteObserver(_analytics)],
  );
  late final PushTokenSync _pushTokenSync = getIt<PushTokenSync>();
  late final RealtimeSession _realtimeSession = getIt<RealtimeSession>();
  late final StreamSubscription<NotificationPayload> _notificationTaps;
  late final StreamSubscription<String?> _authUser;

  @override
  void initState() {
    super.initState();
    _pushTokenSync.start(initial: _authBloc.state, states: _authBloc.stream);
    _realtimeSession.start(
      initial: _authBloc.state.status == AuthStatus.authenticated,
      isAuthenticated: _authBloc.stream.map(
        (state) => state.status == AuthStatus.authenticated,
      ),
    );
    _authUser = _authBloc.stream
        .map((state) => state.user?.id)
        .distinct()
        .listen((id) {
          unawaited(AppLogger.reporter.setUserId(id));
          unawaited(_analytics.setUserId(id));
        });
    final notifications = getIt<NotificationHandler>();
    _notificationTaps = notifications.onTap.listen(_onNotificationTap);
    unawaited(notifications.start());
  }

  /// Deep-links into the app. Only navigates when signed in; the router's
  /// redirect would bounce an unauthenticated user back to login anyway.
  void _onNotificationTap(NotificationPayload payload) {
    final route = payload.route;
    AppLogger.info('Notification tapped → ${route ?? '(no route)'}');
    if (route == null || _authBloc.state.status != AuthStatus.authenticated) {
      return;
    }
    _appRouter.router.go(route);
  }

  @override
  void dispose() {
    unawaited(_notificationTaps.cancel());
    unawaited(_authUser.cancel());
    unawaited(_pushTokenSync.dispose());
    unawaited(_realtimeSession.dispose());
    _appRouter.dispose();
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider(create: (_) => getIt<SettingsCubit>()),
        BlocProvider(create: (_) => getIt<ConnectivityCubit>()),
        BlocProvider(create: (_) => getIt<AppUpdateCubit>()..start()),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) => MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          locale: settings.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: _appRouter.router,
          builder: (_, child) =>
              UpdateGate(child: OfflineBanner(child: child!)),
        ),
      ),
    );
  }
}
