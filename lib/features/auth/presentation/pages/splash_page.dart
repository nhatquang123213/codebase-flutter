import 'package:flutter/material.dart';

import '../../../../core/widgets/loading_view.dart';

/// Shown while `AuthBloc` restores the session; the router leaves it automatically.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: LoadingView());
  }
}
