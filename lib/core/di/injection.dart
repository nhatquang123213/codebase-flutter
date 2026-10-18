import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/auth_injection.dart';
import '../../features/notifications/notifications_injection.dart';
import '../../features/settings/settings_injection.dart';
import '../config/env.dart';
import '../connectivity/connectivity_cubit.dart';
import '../connectivity/connectivity_interceptor.dart';
import '../connectivity/connectivity_service.dart';
import '../events/event_bus.dart';
import '../network/dio_factory.dart';
import '../network/interceptors/auth_interceptor.dart';
import '../realtime/realtime_client.dart';
import '../realtime/realtime_session.dart';
import '../realtime/realtime_transport.dart';
import '../storage/app_preferences.dart';
import '../storage/token_storage.dart';

/// The only service locator in the app. Widgets get blocs from here via
/// `BlocProvider(create: (_) => getIt<XCubit>())`; everything else uses
/// constructor injection.
final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  final eventBus = AppEventBus();
  final connectivity = PlusConnectivityService(Connectivity(), eventBus);
  await connectivity.init();

  getIt
    ..registerSingleton<AppEventBus>(eventBus, dispose: (b) => b.dispose())
    ..registerSingleton<ConnectivityService>(
      connectivity,
      dispose: (_) => connectivity.dispose(),
    )
    ..registerFactory(() => ConnectivityCubit(getIt()))
    ..registerSingleton<AppPreferences>(AppPreferences(prefs))
    ..registerLazySingleton<TokenStorage>(
      () => SecureTokenStorage(const FlutterSecureStorage()),
    )
    ..registerLazySingleton<Dio>(
      () => createDio(
        baseUrl: Env.baseUrl,
        interceptors: [ConnectivityInterceptor(getIt())],
      ),
      instanceName: DioInstance.plain,
    )
    ..registerLazySingleton<Dio>(
      () => createDio(
        baseUrl: Env.baseUrl,
        interceptors: [
          ConnectivityInterceptor(getIt()),
          AuthInterceptor(
            tokenStorage: getIt(),
            refreshClient: getIt(instanceName: DioInstance.plain),
            eventBus: getIt(),
          ),
        ],
      ),
    )
    ..registerLazySingleton<RealtimeClient>(
      () => Env.useMockApi
          ? const NoopRealtimeClient()
          : WebSocketRealtimeClient(
              transport: const WebSocketTransport(),
              uri: Uri.parse(Env.wsUrl),
              tokenProvider: () => getIt<TokenStorage>().readAccessToken(),
              eventBus: getIt(),
            ),
      dispose: (c) => c.disconnect(),
    )
    ..registerLazySingleton<RealtimeSession>(
      () => RealtimeSession(client: getIt(), eventBus: getIt()),
      dispose: (s) => s.dispose(),
    );

  // One call per feature — each feature owns its registrations.
  registerAuthDependencies(getIt);
  registerSettingsDependencies(getIt);
  registerNotificationDependencies(getIt);
}
