import 'package:codebase_flutter/core/extensions/context_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/app_theme.dart';
import 'connectivity_cubit.dart';

/// Slides a strip under the status bar while the device is offline.
/// Installed once via `MaterialApp.builder`, so every page gets it.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityCubit>().state;
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: isOnline
              ? const SizedBox(width: double.infinity)
              : Material(
                  color: context.colors.error,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                        horizontal: AppSpacing.md,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off,
                            size: 16,
                            color: context.colors.onError,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            context.l10n.offlineBanner,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.onError,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        Expanded(
          // The app paints its own status-bar area; only pad when the banner is shown.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: !isOnline,
            child: child,
          ),
        ),
      ],
    );
  }
}
