import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
