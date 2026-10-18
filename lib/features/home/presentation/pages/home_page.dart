import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final settings = context.watch<SettingsCubit>().state;
    final isDark =
        settings.themeMode == ThemeMode.dark ||
        (settings.themeMode == ThemeMode.system &&
            context.theme.brightness == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.logout,
            icon: const Icon(Icons.logout),
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (user != null) ...[
            Text(
              l10n.welcome(user.name),
              style: context.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(user.email, style: context.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.settings, style: context.textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.darkMode),
            value: isDark,
            onChanged: (value) => context.read<SettingsCubit>().setThemeMode(
              value ? ThemeMode.dark : ThemeMode.light,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.language),
            trailing: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'system', label: Text(l10n.systemDefault)),
                const ButtonSegment(value: 'vi', label: Text('VI')),
                const ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {settings.locale?.languageCode ?? 'system'},
              onSelectionChanged: (selection) {
                final code = selection.first;
                context.read<SettingsCubit>().setLocale(
                  code == 'system' ? null : Locale(code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
