import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';

import '../../core/config/env.dart';
import '../../core/firebase/firebase_config.dart';
import '../../core/notifications/local_notification_service.dart';
import '../../core/notifications/notification_handler.dart';
import '../../core/notifications/push_notification_service.dart';
import 'application/push_token_sync.dart';
import 'data/datasources/device_mock_data_source.dart';
import 'data/datasources/device_remote_data_source.dart';
import 'data/repositories/device_token_repository_impl.dart';
import 'domain/repositories/device_token_repository.dart';
import 'domain/usecases/register_device_token_usecase.dart';

void registerNotificationDependencies(GetIt getIt) {
  getIt
    ..registerLazySingleton<PushNotificationService>(
      () => FirebaseConfig.isInitialized
          ? FirebasePushNotificationService(FirebaseMessaging.instance)
          : const NoopPushNotificationService(),
    )
    ..registerLazySingleton<LocalNotificationService>(
      () => LocalNotificationService(FlutterLocalNotificationsPlugin()),
      dispose: (s) => s.dispose(),
    )
    ..registerLazySingleton<NotificationHandler>(
      () => NotificationHandler(push: getIt(), local: getIt()),
      dispose: (h) => h.dispose(),
    )
    ..registerLazySingleton<DeviceRemoteDataSource>(
      () => Env.useMockApi
          ? const DeviceMockDataSource()
          : DeviceRemoteDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<DeviceTokenRepository>(
      () => DeviceTokenRepositoryImpl(getIt()),
    )
    ..registerFactory(() => RegisterDeviceTokenUseCase(getIt()))
    ..registerFactory(
      () => PushTokenSync(push: getIt(), registerToken: getIt()),
    );
}
