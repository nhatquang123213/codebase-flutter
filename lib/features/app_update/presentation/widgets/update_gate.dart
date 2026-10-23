import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../cubit/app_update_cubit.dart';
import '../pages/force_update_page.dart';
import 'open_store_button.dart';

/// Installed via `MaterialApp.builder`: blocks the app on a required update,
/// shows a dismissible strip for an optional one, otherwise renders [child].
class UpdateGate extends StatelessWidget {
  const UpdateGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppUpdateCubit>().state;
    if (state.isBlocking) return ForceUpdatePage(storeUrl: state.storeUrl);
    return Column(
      children: [
        Expanded(child: child),
        if (state.showsPrompt) _UpdatePrompt(state: state),
      ],
    );
  }
}

class _UpdatePrompt extends StatelessWidget {
  const _UpdatePrompt({required this.state});

  final AppUpdateState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: context.colors.primaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.updateAvailableTitle,
                      style: context.textTheme.titleSmall,
                    ),
                    Text(
                      l10n.updateAvailableBody,
                      style: context.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.read<AppUpdateCubit>().dismiss(),
                child: Text(l10n.later),
              ),
              OpenStoreButton(storeUrl: state.storeUrl, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}
