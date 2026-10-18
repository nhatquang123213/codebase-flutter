import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/bloc/app_bloc_observer.dart';
import '../core/config/env.dart';
import '../core/di/injection.dart';
import '../core/firebase/firebase_config.dart';
import '../core/monitoring/crash_reporter.dart';
import '../core/notifications/firebase_background_handler.dart';
import '../core/notifications/local_notification_service.dart';
import '../core/utils/app_logger.dart';

Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(
    Env.matchesNativeFlavor(appFlavor),
    'Native flavor "$appFlavor" does not match FLAVOR=${Env.flavor.name}. '
    'Use `make run-<flavor>` so --flavor and --dart-define-from-file agree.',
  );

  // Firebase must be up before DI so services can decide between the real
  // implementations and the no-op ones (placeholder options → no Firebase).
  await FirebaseConfig.ensureInitialized();
  if (FirebaseConfig.isInitialized) {
    final reporter = CrashlyticsReporter(FirebaseCrashlytics.instance);
    await reporter.init();
    AppLogger.reporter = reporter;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } else {
    AppLogger.warning(
      'Firebase not configured — push notifications & crash reporting disabled',
    );
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.reporter.recordFlutterError(details).ignore();
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Uncaught error', error, stack);
    return true;
  };

  Bloc.observer = const AppBlocObserver();
  await configureDependencies();
  await getIt<LocalNotificationService>().init();

  AppLogger.info('Starting ${Env.flavor.name} → ${Env.baseUrl}');
  runApp(builder());
}
