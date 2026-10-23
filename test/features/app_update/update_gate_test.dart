import 'package:codebase_flutter/core/config/remote_config.dart';
import 'package:codebase_flutter/features/app_update/domain/app_version.dart';
import 'package:codebase_flutter/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:codebase_flutter/features/app_update/presentation/pages/force_update_page.dart';
import 'package:codebase_flutter/features/app_update/presentation/widgets/update_gate.dart';
import 'package:codebase_flutter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryRemoteConfigService config;
  late AppUpdateCubit cubit;

  setUp(() {
    config = InMemoryRemoteConfigService();
    cubit = AppUpdateCubit(
      config: config,
      currentVersion: const AppVersion(1, 0, 0),
      platform: TargetPlatform.android,
    );
  });

  tearDown(() => cubit.close());

  Widget app() => BlocProvider.value(
    value: cubit,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (_, child) => UpdateGate(child: child!),
      home: const Scaffold(body: Text('content')),
    ),
  );

  testWidgets('renders the app when up to date', (tester) async {
    cubit.start();
    await tester.pumpWidget(app());

    expect(find.text('content'), findsOneWidget);
    expect(find.byType(ForceUpdatePage), findsNothing);
  });

  testWidgets('shows a dismissible prompt for an optional update', (
    tester,
  ) async {
    config.update({RemoteConfigKeys.latestVersion: '2.0.0'});
    cubit.start();
    await tester.pumpWidget(app());

    expect(find.text('content'), findsOneWidget);
    expect(find.text('Update available'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pump();

    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('replaces the app when the update is required', (tester) async {
    config.update({RemoteConfigKeys.minSupportedVersion: '2.0.0'});
    cubit.start();
    await tester.pumpWidget(app());

    expect(find.byType(ForceUpdatePage), findsOneWidget);
    expect(find.text('content'), findsNothing);
    // No store url configured → button present but disabled.
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
