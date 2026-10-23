import 'package:flutter/material.dart';

import '../../../../core/extensions/context_x.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/open_store_button.dart';

/// Replaces the whole app while the build is below the minimum version.
class ForceUpdatePage extends StatelessWidget {
  const ForceUpdatePage({required this.storeUrl, super.key});

  final Uri? storeUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.system_update_alt,
                size: 64,
                color: context.colors.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.updateRequiredTitle,
                style: context.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.updateRequiredBody,
                style: context.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              OpenStoreButton(storeUrl: storeUrl),
            ],
          ),
        ),
      ),
    );
  }
}
